local test = require('tests/framework/microtest')
local protocol_http = require('ee/engine/protocol/http_fsb09')

event = {
    post=function(evt)
    end
}

local std = {
    bus = {
        listen = function(key, handler) 
            event[key] = handler
        end
    }
}
local application = {internal={http={}}}
local http_handler = protocol_http.handler
local http_reset = function() return protocol_http.install(std) end
application.internal.fixed_loop = { function() event.loop() end }
application.internal.event_loop = { function(evt) event.ginga(evt) end }

function test_http_fast_post_201()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='_fast',
        method='POST',
        body_content='',
        url='http://example.com/create-user',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='example.com',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 201 OK\r\nContent-Length: 2\r\n\r\nOK\r\n\r\n',
        connection=1
    })

    assert(response.ok == true)
    assert(response.status == 201)
    assert(response.body == '')
    assert(response.error == nil)
end

function test_http_get_200()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\neu',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value=' amo ',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='pudim!',
        connection=1
    })
    
    assert(response.ok == true)
    assert(response.status == 200)
    assert(response.body == 'eu amo pudim!')
    assert(response.error == nil)
end

function test_http_redirect_300()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 300 Redirect\r\nLocation: http://pudim.com.br\r\n\r\n',
        connection=1
    })
    application.internal.fixed_loop[1]()
    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 13\r\n\r\neu amo pudim!',
        connection=2
    })
    
    assert(response.ok == true)
    assert(response.status == 200)
    assert(response.body == 'eu amo pudim!')
    assert(response.error == nil)
end


function test_http_simultaneous_requests()
    http_reset().http.dns_state = 2

    local response1 = {}
    local http1 = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br/chocolate',
        set = function(key, value)
            response1[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }
    local response2 = {}
    local http2 = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br/doce-de-leite',
        set = function(key, value)
            response2[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }
    local response3 = {}
    local http3 = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br/leite-condesado',
        set = function(key, value)
            response3[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }


    http_handler(http3)
    http_handler(http2)
    http_handler(http1)
    application.internal.fixed_loop[1]()
    application.internal.fixed_loop[1]()
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=3
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 28\r\n\r\namo',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 23\r\n\r\namo',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value=' pudim de ',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value=' pudim de doce de leite!',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 19\r\n\r\namo pudim de leite!',
        connection=3
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='chocolate!',
        connection=1
    })

    assert(response1.body == 'amo pudim de chocolate!')
    assert(response2.body == 'amo pudim de doce de leite!')
    assert(response3.body == 'amo pudim de leite!')
end



function test_http_get_200_samsung()
    http_reset().http.dns_state = 0

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://google.com',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.http.dns_state = 3
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='8.8.8.8',
        connection=1
    })
    application.internal.fixed_loop[1]()
    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='8.8.8.8',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 10\r\n\r\ngoogle it!',
        connection=2
    })
    application.internal.http.dns_state = 2

    assert(response.ok  == true)
    assert(response.status == 200)
    assert(response.body == 'google it!')
    assert(response.error == nil)    
end

function test_http_get_200_samsung_first_time()
    http_reset().http.dns_state = 0

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://bing.com',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.http.dns_state = 0
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='1.1.1.1',
        connection=1
    })
    application.internal.fixed_loop[1]()
    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='1.1.1.1',
        connection=2
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 200 OK\r\nContent-Length: 8\r\n\r\nbing it!',
        connection=2
    })
    application.internal.http.dns_state = 2

    assert(response.ok == true)
    assert(response.status == 200)
    assert(response.body == 'bing it!')
    assert(response.error == nil)  
end

function test_http_error_http()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        method='GET',
        body_content='',
        url='https://pudim.com.br/',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()
    
    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'HTTPS is not supported!')
end

function test_http_error_https_redirect()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br/',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 300 Redirect\r\nLocation: https://pudim.com.br\r\n\r\n',
        connection=1
    })
    
    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'HTTPS is not supported!')
end

function test_http_error_too_many_redirect()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='GET',
        body_content='',
        url='http://pudim.com.br/',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    http.p_redirects = 50
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='HTTP/1.1 300 Redirect\r\nLocation: http://pudim.com.br/\r\n\r\n',
        connection=1
    })
    
    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'Too Many Redirects!')
end

function test_http_fast_empty_status_error()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='_fast',
        method='POST',
        body_content='',
        url='http://pudim.com.br/create-user',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        value='some error',
        connection=1
    })
    
    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'some error')
end

function test_http_dns_error()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='POST',
        body_content='',
        url='http://pudim.com',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com',
        error='cannot resolve pudim.com'
    })

    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'cannot resolve pudim.com')
end


function test_http_data_error()
    http_reset().http.dns_state = 2

    local response = {}
    local http = {
        speed='',
        method='POST',
        body_content='',
        url='http://pudim.com.br',
        set = function(key, value)
            response[key] = value
        end,
        promise = function() end,
        resolve = function() end
    }

    http_handler(http)
    application.internal.fixed_loop[1]()

    application.internal.event_loop[1]({
        class='tcp',
        type='connect',
        host='pudim.com.br',
        connection=1
    })
    application.internal.event_loop[1]({
        class='tcp',
        type='data',
        error='some data error',
        connection=1
    })

    assert(response.ok == false)
    assert(response.status == nil)
    assert(response.body == nil)
    assert(response.error == 'some data error')
end

test.unit(_G)
