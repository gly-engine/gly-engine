local test = require('tests/framework/microtest')
local zeebo_util_http = require('source/shared/string/encode/http')

function test_is_ok_status()
    assert(zeebo_util_http.is_ok(200) == true)
    assert(zeebo_util_http.is_ok(201) == true)
    assert(zeebo_util_http.is_ok(299) == true)
    assert(zeebo_util_http.is_ok(199) == false)
    assert(zeebo_util_http.is_ok(300) == false)
end

function test_is_ok_header_with_valid_header()
    local ok, status = zeebo_util_http.is_ok_header('HTTP/1.1 200 OK')
    assert(ok == true)
    assert(status == 200)
end

function test_is_ok_header_with_invalid_header()
    local ok, status = zeebo_util_http.is_ok_header('invalid header')
    assert(ok == false)
    assert(status == nil)
end

function test_is_ok_header_with_redirect_status()
    local ok, status = zeebo_util_http.is_ok_header("HTTP/1.1 302 Found")
    assert(ok == false)
    assert(status == 302)
end

function test_is_ok_header_with_client_error_status()
    local ok, status = zeebo_util_http.is_ok_header("HTTP/1.1 404 Not Found")
    assert(ok == false)
    assert(status == 404)
end

function test_is_ok_header_with_server_error_status()
    local ok, status = zeebo_util_http.is_ok_header("HTTP/1.1 500 Internal Server Error")
    assert(ok == false)
    assert(status == 500)
end


function test_is_redirect_valid()
    assert(zeebo_util_http.is_redirect(300) == true)
    assert(zeebo_util_http.is_redirect(301) == true)
    assert(zeebo_util_http.is_redirect(399) == true)
    assert(zeebo_util_http.is_redirect(299) == false)
    assert(zeebo_util_http.is_redirect(400) == false)
end


function test_create_request_overrides()
    local request = zeebo_util_http.create_request('GET', '/')
        .add_imutable_header('h1', '1')
        .add_mutable_header('h1', '2')
        .add_mutable_header('h2', '3')
        .add_imutable_header('h2', '4')
        .add_mutable_header('h2', '5')
        .add_imutable_header('h3', '6')
        .add_mutable_header('h4', '7')
        .add_custom_headers({'h3', 'h4'}, {h3='8', h4='9'})
        .add_custom_headers({'h5', 'h6'}, {h5='10', h6='11'})
        .add_imutable_header('h3', '13')
        .add_mutable_header('h5', '14')
        .add_imutable_header('h6', '15')
        .add_mutable_header('h7', '16')
        .to_http_protocol()

    assert(request == 'GET / HTTP/1.1\r\nh1: 1\r\nh2: 4\r\nh3: 6\r\nh4: 9\r\nh5: 10\r\nh6: 15\r\nh7: 16\r\n\r\n')
end

function test_create_request_conditions()
    local request = zeebo_util_http.create_request('HEAD', '/')
        .add_imutable_header('h1', '1', nil)
        .add_imutable_header('h2', '2', false)
        .add_imutable_header('h3', '3', true)
        .add_mutable_header('h4', '4', nil)
        .add_mutable_header('h5', '5', false)
        .add_mutable_header('h6', '6', true)
        .to_http_protocol()

    assert(request == 'HEAD / HTTP/1.1\r\nh1: 1\r\nh3: 3\r\nh4: 4\r\nh6: 6\r\n\r\n')
end

function test_create_request_add_body_post()
    local request = zeebo_util_http.create_request('POST', '/')
        .add_imutable_header('Content-Length', 9)
        .add_body_content('foo bar z')
        .to_http_protocol()

    assert(request == 'POST / HTTP/1.1\r\nContent-Length: 9\r\n\r\nfoo bar z\r\n\r\n')
end

function test_create_request_no_body_in_get()
    local request = zeebo_util_http.create_request('GET', '/')
        .add_body_content('foo bar z')
        .to_http_protocol()
    assert(request == 'GET / HTTP/1.1\r\n\r\n')
end

function test_create_request_wget_get()
    local request = zeebo_util_http.create_request('GET', 'http://example.com')
        .add_imutable_header('Accept', 'application/json')
        .to_wget_cmd()
    assert(request == 'wget --quiet --output-document=- --header="Accept: application/json" http://example.com')
end

function test_create_request_wget_post_with_body()
    local request = zeebo_util_http.create_request('POST', 'http://example.com')
        .add_imutable_header('Content-Type', 'application/json')
        .add_body_content('{"key": "value"}')
        .to_wget_cmd()
    assert(request == 'wget --quiet --output-document=- --method=POST --header="Content-Type: application/json" --body-data="{\\"key\\": \\"value\\"}" http://example.com')
end

function test_create_request_wget_with_headers()
    local request = zeebo_util_http.create_request('PUT', 'http://example.com')
        .add_imutable_header('Authorization', 'Bearer token')
        .add_imutable_header('Content-Type', 'application/json')
        .add_body_content('{"name": "test"}')
        .to_wget_cmd()

    assert(request == 'wget --quiet --output-document=- --method=PUT --header="Authorization: Bearer token" --header="Content-Type: application/json" --body-data="{\\"name\\": \\"test\\"}" http://example.com')
end

function test_create_request_wget_head()
    local request = zeebo_util_http.create_request('HEAD', 'http://example.com')
        .to_wget_cmd()
    assert(request == 'wget --quiet --output-document=- --method=HEAD http://example.com')
end

function test_not_status_disables_print_http_status()
    local request = zeebo_util_http.create_request('GET', '/')
    request.not_status()
    local result = request:not_status()
    assert(request.print_http_status == false)
    assert(result == request)
end

test.unit(_G)
