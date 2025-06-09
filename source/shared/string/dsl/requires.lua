--! @defgroup Languages
--! @{
--! 
--! @defgroup dsl
--! @{
--! 
--! @defgroup require Import
--! @{
--!
--! <b>Do not use the standard @c require() from Lua in Gly-Engine games or apps.</b>
--! Gly-Engine provides an advanced include system that handles module loading in the best way for you.
--! In addition, user modules are automatically imported via @ref load "std.node.load".
--!
--! @par Backus-Naur Form
--! @startebnf
--! optionalLib = ( ? a - z 0 - 9 ? ), [ '.', ( ? a - z 0 - 9 ? ) ], '?' ;
--! requiredLib = ( ? a - z 0 - 9 ? ), [ '.', ( ? a - z 0 - 9 ? ) ];
--! allAvaliableLibs = '*' ;
--! require = { requiredLib | optionalLib }, [ allAvaliableLibs ];
--! @endebnf
--! @endebnf
--!
--! @par Usage
--! @code{.java}
--! local P = {
--!     meta = {}
--!     config = {
--!         require = 'http media.video media.audio? *'
--!     }
--! }
--! 
--! return P
--! @endcode
--!
--! @}
--! @}
--! @}

local function encode(dsl_string)
  local spec = {
    list = {},
    required = {},
    all = false
  }

  for entry in (dsl_string or ''):gmatch("[^%s]+") do
    if entry == "*" then
      spec.all = true
    else
      local is_optional = entry:sub(-1) == "?"
      local name = is_optional and entry:sub(1, -2) or entry
      spec.list[#spec.list + 1] = name
      spec.required[#spec.required + 1] = not is_optional
    end
  end
  return spec
end

local function missing(spec, imported_list)
  local result = {}
  local imported = {}

  do
    local index = 1
    while imported_list[index] do
      imported[imported_list[index]] = true
      index = index + 1
    end
  end

  do
    local index = 1
    while spec.list[index] do
      local name = spec.list[index]
      if spec.required[index] and not imported[name] then
        result[#result + 1] = name
      end
      index = index + 1
    end
  end
  
  return result
end

local function should_import(spec, libname)
  local index = 1
  while spec.list[index] do
    if spec.list[index] == libname then return true end
    index = index + 1
  end
  return spec.all
end

local P = {
  encode = encode,
  missing = missing,
  should_import = should_import
}

return P
