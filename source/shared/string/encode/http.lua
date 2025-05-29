local function is_ok(status)
    return (status and 200 <= status and status < 300) or false
end

local function is_ok_header(header)
    local status = tonumber(header:match('HTTP/%d.%d (%d%d%d)'))
    local ok = status and is_ok(status) or false
    return ok, status
end

local function is_redirect(status)
    return (status and 300 <= status and status < 400) or false
end

local function get_content(response)
    local header, body = response:match("^(.-\r\n\r\n)(.*)")
    if not header or not body then return nil end
    local content_length = tonumber(header:match("Content%-Length:%s*(%d+)"))
    if not content_length then return nil end
    if #body < content_length then return nil end
    local content = body:sub(1, content_length)
    return content
end

local function get_user_agent()
    return 'Ginga (GlyOS;SmartTv/Linux)'
end

local function url_search_param(param_list, param_dict)
    local index, params = 1, ''
    while param_list and param_dict and index <= #param_list do
        local param = param_list[index]
        local value = param_dict[param]
        if #params == 0 then
            params = params..'?'
        else
            params = params..'&'
        end
        params = params..param:gsub(' ', '%20')..'='..(value or ''):gsub(' ', '%20')
        index = index + 1
    end
    return params
end

local function create_request(method, uri)
    local self = {
        body_content = '',
        header_list = {},
        header_dict = {},
        header_imutable = {},
        print_http_status = true
    }

    self.add_body_content = function (body)
        self.body_content = self.body_content..(body or '')
        return self
    end

    self.add_imutable_header = function (header, value, cond)
        if cond == false then return self end
        if self.header_imutable[header] == nil then
            self.header_list[#self.header_list + 1] = header
            self.header_dict[header] = value
        elseif self.header_imutable[header] == false then
            self.header_dict[header] = value
        end
        self.header_imutable[header] = true
        return self
    end

    self.add_mutable_header = function (header, value, cond)
        if cond == false then return self end
        if self.header_imutable[header] == nil then
            self.header_list[#self.header_list + 1] = header
            self.header_imutable[header] = false
            self.header_dict[header] = value
        end
        return self
    end

    self.add_custom_headers = function(header_list, header_dict)
        local index = 1
        while header_list and #header_list >= index do
            local header = header_list[index]
            local value = header_dict[header]

            if self.header_imutable[header] == nil then
                self.header_list[#self.header_list + 1] = header
                self.header_imutable[header] = false
                self.header_dict[header] = value
            elseif self.header_imutable[header] == false then
                self.header_dict[header] = value
            end

            index = index + 1
        end
        return self
    end

    self.not_status = function()
        self.print_http_status = false
        return self
    end

    self.to_http_protocol = function ()
        local index = 1
        local request = method..' '..uri..' HTTP/1'..'.1\r\n'
        
        while index <= #self.header_list do
            local header = self.header_list[index]
            local value = self.header_dict[header]
            request = request..header..': '..value..'\r\n'
            index = index + 1
        end
        
        request = request..'\r\n'

        if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
            request = request..self.body_content..'\r\n\r\n'
        end

        return request, function() end
    end

    self.to_curl_cmd = function ()
        local index = 1
        local request = 'curl -L -'..'-silent -'..'-insecure '

        if self.print_http_status then
            request = request..'-w "\n%{http_code}" '
        end

        if method == 'HEAD' then
            request = request..'-'..'-HEAD '
        else
            request = request..'-X '..method..' '
        end
        
        while index <= #self.header_list do
            local header = self.header_list[index]
            local value = self.header_dict[header]
            request = request..'-H "'..header..': '..value..'" '
            index = index + 1
        end

        if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
            request = request..'-d \''..self.body_content..'\' '
        end

        request = request..uri

        return request, function() end
    end

    self.to_wget_cmd = function ()
        local request = 'wget -'..'-quiet -'..'-output-document=-'
    
        if method == 'HEAD' then
            request = request..' -'..'-method=HEAD'
        elseif method ~= 'GET' then
            request = request..' -'..'-method='..method
        end
    
        for index, header in ipairs(self.header_list) do
            local value = self.header_dict[header]
            if value then
                local escaped_value = value:gsub('"', '\\"')
                request = request..' -'..'-header="'..header..': '..escaped_value..'"'
            end
        end
    
        if method ~= 'GET' and method ~= 'HEAD' and #self.body_content > 0 then
            local escaped_body = self.body_content:gsub('"', '\\"')
            request = request..' -'..'-body-data="'..escaped_body..'"'
        end
    
        request = request..' '..uri
    
        return request, function() end
    end

    return self
end

return {
    is_ok=is_ok,
    is_ok_header=is_ok_header,
    is_redirect=is_redirect,
    get_content=get_content,
    get_user_agent=get_user_agent,
    url_search_param=url_search_param,
    create_request=create_request
}
