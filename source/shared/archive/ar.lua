local function trim_field(field)
    return field:match('^%s*(.-)%s*$')
end

local function resolve_gnu_name(context, index)
    local string_table = context.string_table
    if not string_table then
        error('missing ar string table')
    end

    local offset = string_table.offset + index
    local limit = string_table.offset + string_table.size - 1
    local terminator = string_table.body:find('/\n', offset, true)
    if offset > limit or not terminator or terminator > limit then
        error('invalid ar string table reference')
    end
    return string_table.body:sub(offset, terminator - 1)
end

local function emit_member(context, name, body, offset, size)
    if name == '//' then
        context.string_table = {
            body = body,
            offset = offset,
            size = size
        }
        return
    end
    if name == '/' or name == '/SYM64/' then
        return
    end

    local reference = name:match('^/(%d+)$')
    local embedded = tonumber(name:match('^#1/(%d+)$'))
    if reference then
        name = resolve_gnu_name(context, tonumber(reference))
    elseif embedded then
        if embedded > size then
            error('invalid ar embedded name')
        end
        name = body:sub(offset, offset + embedded - 1):match('^[^\0]*')
        offset = offset + embedded
        size = size - embedded
    elseif name:sub(-1) == '/' then
        name = name:sub(1, -2)
    end

    if name:sub(1, 9) ~= '__.SYMDEF' then
        context.handler({
            name = name,
            body = body,
            offset = offset,
            size = size
        })
    end
end

local function parse(body)
    if type(body) ~= 'string' or body:sub(1, 8) ~= '!<arch>\n' then
        error('invalid ar magic')
    end

    local members = {}
    local context = {
        handler = function(member)
            members[#members + 1] = member
        end
    }
    local length = #body
    local offset = 9

    while offset <= length do
        if offset + 59 > length then
            error('truncated ar header')
        end
        local header = body:sub(offset, offset + 59)
        if header:sub(59, 60) ~= '`\n' then
            error('invalid ar header')
        end

        local size = tonumber(header:sub(49, 58):match('^%s*(%d+)%s*$'))
        if not size then
            error('invalid ar member size')
        end
        local data_offset = offset + 60
        if data_offset + size - 1 > length then
            error('truncated ar member')
        end

        emit_member(context, trim_field(header:sub(1, 16)), body, data_offset, size)
        offset = data_offset + size + size % 2
    end
    return members
end

local function read_bytes(self, size)
    if size == 0 then return '' end

    local chunk = self.chunks[self.head]
    local available = #chunk - self.head_offset + 1
    if size <= available then
        local data = self.head_offset == 1 and size == #chunk
            and chunk
            or chunk:sub(self.head_offset, self.head_offset + size - 1)
        self.head_offset = self.head_offset + size
        self.length = self.length - size
        if self.head_offset > #chunk then
            self.chunks[self.head] = nil
            self.head = self.head + 1
            self.head_offset = 1
        end
        return data
    end

    local parts = {}
    local count = 0
    local remaining = size
    while remaining > 0 do
        chunk = self.chunks[self.head]
        available = #chunk - self.head_offset + 1
        local take = remaining < available and remaining or available
        count = count + 1
        parts[count] = self.head_offset == 1 and take == #chunk
            and chunk
            or chunk:sub(self.head_offset, self.head_offset + take - 1)
        self.head_offset = self.head_offset + take
        self.length = self.length - take
        remaining = remaining - take
        if self.head_offset > #chunk then
            self.chunks[self.head] = nil
            self.head = self.head + 1
            self.head_offset = 1
        end
    end
    return table.concat(parts)
end

local function step(self, budget)
    local remaining = budget or 1
    while remaining > 0 and self.length >= self.needed do
        remaining = remaining - 1

        if self.stage == 'member' then
            if self.needed == 0 then
                emit_member(self, self.name, '', 1, 0)
            else
                local chunk = self.chunks[self.head]
                local available = #chunk - self.head_offset + 1
                if self.needed <= available then
                    local offset = self.head_offset
                    self.head_offset = self.head_offset + self.needed
                    self.length = self.length - self.needed
                    emit_member(self, self.name, chunk, offset, self.member_size)
                    if self.head_offset > #chunk then
                        self.chunks[self.head] = nil
                        self.head = self.head + 1
                        self.head_offset = 1
                    end
                else
                    local data = read_bytes(self, self.needed)
                    emit_member(self, self.name, data, 1, self.member_size)
                end
            end
            self.stage = 'header'
            self.needed = 60
        else
            local data = read_bytes(self, self.needed)
            if self.stage == 'magic' then
                if data ~= '!<arch>\n' then
                    error('invalid ar magic')
                end
                self.stage = 'header'
                self.needed = 60
            else
                if data:sub(59, 60) ~= '`\n' then
                    error('invalid ar header')
                end
                local size = tonumber(data:sub(49, 58):match('^%s*(%d+)%s*$'))
                if not size then
                    error('invalid ar member size')
                end
                self.name = trim_field(data:sub(1, 16))
                self.member_size = size
                self.stage = 'member'
                self.needed = size + size % 2
            end
        end
    end

    if self.input_done and self.length < self.needed then
        if self.stage ~= 'header' or self.length ~= 0 then
            error('truncated ar archive')
        end
        self.closed = true
    end
    return self.closed
end

local function push(self, data)
    if self.input_done then
        error('ar stream is closed')
    end
    if #data > 0 then
        self.tail = self.tail + 1
        self.chunks[self.tail] = data
        self.length = self.length + #data
    end
end

local function finish(self)
    self.input_done = true
end

local function close(self)
    finish(self)
    while not self.closed do
        step(self, 64)
    end
end

local function new(handler)
    return {
        handler = handler,
        chunks = {},
        head = 1,
        tail = 0,
        head_offset = 1,
        length = 0,
        stage = 'magic',
        needed = 8,
        input_done = false,
        closed = false,
        push = push,
        finish = finish,
        step = step,
        close = close
    }
end

return {
    new = new,
    parse = parse
}
