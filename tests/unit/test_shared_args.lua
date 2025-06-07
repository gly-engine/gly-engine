local test = require('tests/framework/microtest')
local zeebo_args = require('source/shared/string/parse/args')

function test_shared_args_get_basic()
    local args = {'--option', 'value'}
    assert(zeebo_args.get(args, 'option', 'default') == 'value')
end

function test_shared_args_get_default_value()
    local args = {'--other', 'value'}
    assert(zeebo_args.get(args, 'option', 'default') == 'default')
end

function test_shared_args_get_missing_argument()
    local args = {'--option'}
    assert(zeebo_args.get(args, 'option', 'default') == 'default')
end

function test_shared_args_get_no_arguments()
    local args = {}
    assert(zeebo_args.get(args, 'option', 'default') == 'default')
end

function test_shared_args_has_true()
    local args = {'--option'}
    assert(zeebo_args.has(args, 'option') == true)
end

function test_shared_args_has_false()
    local args = {'--other'}
    assert(zeebo_args.has(args, 'option') == false)
end

function test_shared_args_has_no_arguments()
    local args = {}
    assert(zeebo_args.has(args, 'option') == false)
end

function test_shared_args_param_basic()
    local args = {'value1', '--flag', 'param1', '--flag2', 'param2', 'value2'}
    local args_get = {'flag', 'flag2'}
    assert(zeebo_args.param(args, args_get, 1, 'default') == 'value1')
    assert(zeebo_args.param(args, args_get, 2, 'default') == 'value2')
end

function test_shared_args_param_position_out_of_range()
    local args = {'value1', '--flag', 'param1'}
    local args_get = {'flag'}
    assert(zeebo_args.param(args, args_get, 2, 'default') == 'default')
end

function test_shared_args_param_no_arguments()
    local args = {}
    local args_get = {'flag'}
    assert(zeebo_args.param(args, args_get, 1, 'default') == 'default')
end

function test_shared_args_param_single_argument()
    local args = {'value1'}
    local args_get = {}
    assert(zeebo_args.param(args, args_get, 1, 'default') == 'value1')
end

test.unit(_G)
