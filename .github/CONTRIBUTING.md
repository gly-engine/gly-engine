# CONTRIBUTING

## snake case

Write everything in Snake Case, let it be as detailed or magical as you prefer.

# _p _f _err files

variables that refer to strings when the type is string can be the name itself, the moment you use a fs utility use the prefix _p and when opening the file use the prefix _f, error checking should be suffixed with _err.

```lua
local function write_helloworld(outfile)
    local outfile_p = str_fs.file(outfile)
    local outfile_f, outfile_err = io.open(outfile_p.get_fullfilepath(), 'w')

    if outfile_f then
        outfile_f:write('hello world!')
        outfile_f:close()
    end

    return outfile_f ~= nil, outfile_err
end
```

## while / repeat

avoid using `for`, and never use it to iterate a table that is treated as an array, especially avoid `ipairs()` and `pairs()` unless necessary but never at runtime only in bootstraping.

```lua
-- DONT
for index, value in pairs(array) do
    print(index, value)
end

-- DO
local index = 1
while index <= #array do
    print(index, value[index])
    index = index + 1
end
```

 - `pairs()` pairs does not return the array in the order it was appended and also has costly performance according to the **lua gem book**.
 - although `ipairs()` is the correct usage for array-style tables (starting with 1 and sequentially), it is very easy to confuse or mistype, especially for beginners in lua.
 - using `for` makes it difficult to have a single code flow, and also to correctly measure code coverage on each branch.
 - preferring to use `while` instead `for` reduces friction for new contributors unfamiliar with the lua language.

# inverse list

```lua
-- DONT
local function add_something(self, key, value)
    self.something[key] = value
end

local function print_somethingds(self)
    for key, value in pairs(self.something) do
        print(key, value)
    end
end

-- DO
local function add_something(self, key, value)
    if not self.something_dict[key] then
        #index = self.something_list + 1
        self.something_list[index] = key
    end
    self.something_dict[key] = value
end

local function print_somethingds(self)
    local index, lenght = 1, #self.something_list
    while index <= lenght do
        local key = self.something_list[index]
        local value = self.something_dict[key]
        print(key, value)
        index = index + 1
    end
end
```

 - allows you to have control of all the keys added and iterate the order in which they were appended.
 - reduces friction with new contributors

## module as table

every lua file must return a table, even if there is only one function, and there cannot be changes to global variables.
_(except for the `main.lua` of the native core)_

```lua
-- DONT
local function mylib()
end

return mylib
end

-- DO
local function mylib()
end

local P = {
    mylib = mylib
}

return P
```

## ⁠consistent types

variables should never have two types in their lifecycle, even nil (except tables that can be cleared)

```lua
-- DONT
local foo = '5'
foo = tonumber(foo)

-- DO
local foo = '5'
local bar = tonumber(foo)
```

 - this is held in the cli and engine codebase using [luau-analyze](https://luau.org/lint) by roblox.
 - do not create local variables without values ​​because linter will understand them as type `any`.
 - you can create empty functions or default values ​​to always keep the same type.

## mathlib is optional

lua's math lib depends on math clib, and it is heavy, and may not be statically compiled for certain embedded devices,
so consider supporting such devices, provide the feature if there is one, otherwise find a way to continue without full support.

```lua
local math = require('math')

-- DONT
local pi2 = math.pi*2

-- DO
assert(math, 'math is required')
local pi2 = math.pi*2

-- DO (alternative)
local pi2 = math and (math.pi * 2) or (3.14 * 2)

-- DO (alternative)
if math then
    local pi2 = math.pi * 2
    -- continue feature only math exist.
end
```

## pipelines

prefer to create constructor pipelines with lazy evaluation, it would be better than a function full of parameters, or controlling the append of a table array-like.

```lua
-- DONT
local result = function_with_many_params(foo, bar, zip, zig, zag, zoom, biz, baz, zeep)

-- DO
local ok, result = function_pipeline_start()
    :set_foo(foo)
    :set_bar(bar)
    :add(zip)
    :add(zig)
    :add(zag)
    :add(zom)
    :configure(biz, baz, zeep)
    :build() -- also: apply() / run() / apply()
```

## no metatable

Do not use metatables because this hinders compatibility _(such as subtle changes in the `__gc` key and also `__index` in each version of lua)_, but it also makes interpolation with other languages ​​or even C API more difficult or complex, make your code simple, explicit and friendly for those who do not know the magical powers of lua language.

## no oop

Object-oriented programming is prohibited, prefer to do something more functional, without classes or inheritance.

## no deps

Don't create a dependency on something that you can do in a few lines _(less than 1000 lines for example)_, or has simple logic, sometimes a dependency brings a lot of resources and you only need one feature.

 - If a dependency is extremely necessary, vendorize it!

## ⁠no floats

do not write floating point numbers, you can use them as fractional, but it must be an integer-only lua friendly code, including the parser's lack of support for understanding doubles.

```lua
-- DONT
local half = 0.5

-- DO
local half = 1/2
```

 - there is a [`ci_floatcheck.lua`](https://github.com/gly-engine/gly-engine/blob/main/tools/ci_floatcheck.lua) script that checks for this and is in the pipeline.
 - script doesn't know strings, so don't `'HTTP 1.1'` instead do `'HTTP 1'..'.1'`

## no `"--"`

do not use `--` (minus minus) inside strings, only in comments, as the bundler does not have a complete parser, and adding better support for this would make regular expressions much more complex.

```lua
-- DONT
local flag = '--hello'

-- DO
local flag = '-'..'-hello'
```

## only ascii

No non-ascii characters can be used in engine and cli examples or sourcecode, this hinders such broad compatibility, and may cause unicode breaks.

 - there is a [`ci_asciicheck.lua`](https://github.com/gly-engine/gly-engine/blob/main/tools/ci_asciicheck.lua) script that checks for this and is in the pipeline.
