local str_http = require('source/shared/string/encode/http')
local str_url = require('source/shared/string/encode/url')

local function http_handler(self)
    local params = str_url.search_param(self.param_list, self.param_dict)
    local command, cleanup = str_http.create_request(self.method, self.url..params)
        .add_custom_headers(self.header_list, self.header_dict)
        .add_body_content(self.body_content)
        .to_curl_cmd()

    local handle = io and io.popen and io.popen(command)

    if handle then
        local stdout = handle:read("*a")
        local ok, stderr = handle:close()
        local index = stdout:find("[^\n]*$") or 1
        local status = tonumber(stdout:sub(index))
        if not ok then
            self.set('ok', false)
            self.set('error', stderr or stdout or 'unknown error!')
        else
            self.set('ok', 200 <= status and status < 300)
            self.set('body', stdout:sub(1, index - 2))
            self.set('status', status)
        end        
    else 
        self.set('ok', false)
        self.set('error', 'failed to spawn process!')
    end

    cleanup()
end

local P = {
    handler = http_handler
}

return P
