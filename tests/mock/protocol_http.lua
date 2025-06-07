local function http_handler(requests)
    return function (self)
        local request = self.url and requests[self.url]
        local status = request and request.status
        local body = request and request.body

        if type(status) == 'function' then
            status = status(self)
        end
        if type(body) == 'function' then
            body = body(self)
        end

        self.set('ok', request and request.ok or false)
        self.set('status', status)
        self.set('body', body)
        self.set('error', nil)

        if not self.url then
            self.set('error', 'URL not set!')
        elseif not request then
            self.set('status', 404) 
        end
    end
end

local P = {
    requests = http_handler
}

return P;