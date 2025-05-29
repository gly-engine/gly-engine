local http_util = require('src/lib/util/http')

local function http_handler(self)
    local params = http_util.url_search_param(self.param_list, self.param_dict)
    local command, cleanup = http_util.create_request(self.method, self.url..params)
        .add_custom_headers(self.header_list, self.header_dict)
        .add_body_content(self.body_content)
        .to_wget_cmd()

    local handle = io and io.popen and io.popen(command..'; echo $?')

    if handle then
        local stdout = handle:read("*a")
        local ok = handle:close()
        local index = stdout:find("(%d+)\n$")
        local ok2 = stdout:sub(index):find('0')
        if not ok or not ok2 then
            self.std.http.ok = false
            self.std.http.error = 'unknown error!'
        else
            self.std.http.ok = 200
            self.std.http.body = stdout:sub(1, index - 2)
            self.std.http.status = true
        end        
    else 
        self.std.http.ok = false
        self.std.http.error = 'failed to spawn process!'
    end

    cleanup()
end

local P = {
    handler = http_handler
}

return P
