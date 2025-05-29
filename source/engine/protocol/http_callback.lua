local http_util = require('src/lib/util/http')

local callbacks = {
    ['async-promise'] = function(self)
        return self:promise()
    end,
    ['async-resolve'] = function(self)
        return self:resolve()
    end,
    ['get-url'] = function(self)
        return self.url
    end,
    ['get-fullurl'] = function(self)
        return self.url..http_util.url_search_param(self.param_list, self.param_dict)
    end,
    ['get-method'] = function(self)
        return self.method
    end,
    ['get-body'] = function(self)
        return self.body_content
    end,
    ['get-param-count'] = function(self)
        return #self.param_list
    end,
    ['get-param-name'] = function(self, data)
        return self.param_list[self.data]
    end,
    ['get-param-data'] = function(self, data)
        return self.param_dict[self.data] or self.param_dict[self.param_list[self.data]]
    end,
    ['get-header-count'] = function(self)
        return #self.header_list
    end,
    ['get-header-name'] = function(self, data)
        return self.header_list[self.data]
    end,
    ['get-header-data'] = function(self, data)
        return self.heeader_dict[self.data] or self.heeader_dict[self.header_list[self.data]]
    end,
    ['set-status'] = function(self, data)
        self.set('status', data)
        self.set('ok', http_util.is_ok(data))
    end,
    ['set-error'] = function(self, data)
        self.set('error', data)
    end,
    ['set-ok'] = function(self, data)
        self.set('ok', data)
    end,
    ['set-body'] = function(self, data)
        self.set('body', data)
    end,
    ['add-body-data'] = function(self, data, std)
        self.set('body', (std.http.body or '')..data)
    end    
}

local function native_http_callback(self, evt, data, std)
    if not callbacks[evt] then
        error('http evt '..evt..' not exist!')
    end
    return callbacks[evt](self, data, std)
end

local P = {
    func = native_http_callback
}

return P
