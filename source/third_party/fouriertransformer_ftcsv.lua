local function m58c629bdadd0()
local ftcsv = {}
local sbyte = string.byte
local ssub = string.sub
local luaCompatibility = {}
if type(jit) == 'table' or _ENV then
luaCompatibility.load = _G.load
else
luaCompatibility.load = loadstring
end
if type(jit) == 'table' then
luaCompatibility.LuaJIT = true
function luaCompatibility.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
local currentChar, nextChar = sbyte(inputString, i), nil
while i <= inputLength do
nextChar = sbyte(inputString, i+1)
if currentChar == quote and nextChar == quote then
doubleQuoteEscape = true
i = i + 2
currentChar = sbyte(inputString, i)
elseif currentChar == quote and nextChar ~= quote then
return i-1, doubleQuoteEscape
else
i = i + 1
currentChar = nextChar
end
end
end
else
luaCompatibility.LuaJIT = false
function luaCompatibility.findClosingQuote(i, inputLength, inputString, quote, doubleQuoteEscape)
local j, difference
i, j = inputString:find('"+', i)
if j == nil then
return nil
end
difference = j - i
if difference >= 1 then doubleQuoteEscape = true end
if difference % 2 == 1 then
return luaCompatibility.findClosingQuote(j+1, inputLength, inputString, quote, doubleQuoteEscape)
end
return j-1, doubleQuoteEscape
end
end
local function determineRealHeaders(headerField, fieldsToKeep)
local realHeaders = {}
local headerSet = {}
for i = 1, #headerField do
if not headerSet[headerField[i]] then
if fieldsToKeep ~= nil and fieldsToKeep[headerField[i]] then
table.insert(realHeaders, headerField[i])
headerSet[headerField[i]] = true
elseif fieldsToKeep == nil then
table.insert(realHeaders, headerField[i])
headerSet[headerField[i]] = true
end
end
end
return realHeaders
end
local function determineTotalColumnCount(headerField, fieldsToKeep)
local totalColumnCount = 0
local headerFieldSet = {}
for _, header in pairs(headerField) do
if not headerFieldSet[header] and
(fieldsToKeep == nil or fieldsToKeep[header]) then
headerFieldSet[header] = true
totalColumnCount = totalColumnCount + 1
end
end
return totalColumnCount
end
local function generateHeadersMetamethod(finalHeaders)
for _, headers in ipairs(finalHeaders) do
if headers:find("]") then
return nil
end
end
local rawSetup = "local t, k, _ = ... \
rawset(t, k, {[ [[%s]] ]=true})"
rawSetup = rawSetup:format(table.concat(finalHeaders, "]] ]=true, [ [["))
return luaCompatibility.load(rawSetup)
end
local function parseString(inputString, i, options)
local inputLength = options.inputLength or #inputString
local currentChar, nextChar = sbyte(inputString, i), nil
local skipChar = 0
local field
local fieldStart = i
local fieldNum = 1
local lineNum = 1
local lineStart = i
local doubleQuoteEscape, emptyIdentified = false, false
local skipIndex
local charPatternToSkip = "[" .. options.delimiter .. "\r\n]"
local CR = sbyte("\r")
local LF = sbyte("\n")
local quote = sbyte('"')
local delimiterByte = sbyte(options.delimiter)
local headersMetamethod = options.headersMetamethod
local fieldsToKeep = options.fieldsToKeep
local ignoreQuotes = options.ignoreQuotes
local headerField = options.headerField
local endOfFile = options.endOfFile
local buffered = options.buffered
local outResults = {}
if headerField == nil then
headerField = {}
local headerMeta = {__index = function(_, key) return key end}
setmetatable(headerField, headerMeta)
end
if headersMetamethod then
setmetatable(outResults, {__newindex = headersMetamethod})
end
outResults[1] = {}
local totalColumnCount = options.totalColumnCount or determineTotalColumnCount(headerField, fieldsToKeep)
local function assignValueToField()
if fieldsToKeep == nil or fieldsToKeep[headerField[fieldNum]] then
if ignoreQuotes == false and sbyte(inputString, i-1) == quote then
field = ssub(inputString, fieldStart, i-2)
else
field = ssub(inputString, fieldStart, i-1)
end
if doubleQuoteEscape then
field = field:gsub('""', '"')
end
doubleQuoteEscape = false
emptyIdentified = false
if headerField[fieldNum] ~= nil then
outResults[lineNum][headerField[fieldNum]] = field
else
error('ftcsv: too many columns in row ' .. options.rowOffset + lineNum)
end
end
end
while i <= inputLength do
nextChar = sbyte(inputString, i+1)
if ignoreQuotes == false and currentChar == quote and nextChar == quote then
skipChar = 1
fieldStart = i + 2
emptyIdentified = true
elseif ignoreQuotes == false and currentChar == quote and nextChar ~= quote and fieldStart == i then
fieldStart = i + 1
if emptyIdentified then
fieldStart = fieldStart - 2
emptyIdentified = false
end
skipChar = 1
i, doubleQuoteEscape = luaCompatibility.findClosingQuote(i+1, inputLength, inputString, quote, doubleQuoteEscape)
elseif currentChar == delimiterByte then
assignValueToField()
fieldNum = fieldNum + 1
fieldStart = i + 1
elseif (currentChar == LF or currentChar == CR) then
assignValueToField()
if (currentChar == CR and nextChar == LF) then
skipChar = 1
fieldStart = fieldStart + 1
end
if fieldNum < totalColumnCount then
if buffered and lineNum == 1 and fieldNum == 1 and field == "" then
fieldStart = i + 1 + skipChar
lineStart = fieldStart
else
error('ftcsv: too few columns in row ' .. options.rowOffset + lineNum)
end
else
lineNum = lineNum + 1
outResults[lineNum] = {}
fieldNum = 1
fieldStart = i + 1 + skipChar
lineStart = fieldStart
end
elseif luaCompatibility.LuaJIT == false then
skipIndex = inputString:find(charPatternToSkip, i)
if skipIndex then
skipChar = skipIndex - i - 1
end
end
if i == nil then
if buffered then
outResults[lineNum] = nil
return outResults, lineStart
else
error("ftcsv: can't find closing quote in row " .. options.rowOffset + lineNum ..
". Try running with the option ignoreQuotes=true if the source incorrectly uses quotes.")
end
end
i = i + 1 + skipChar
if (skipChar > 0) then
currentChar = sbyte(inputString, i)
else
currentChar = nextChar
end
skipChar = 0
end
if buffered and not endOfFile then
outResults[lineNum] = nil
return outResults, lineStart
end
assignValueToField()
if fieldNum < totalColumnCount then
if fieldNum == 1 and field == "" then
outResults[lineNum] = nil
else
error('ftcsv: too few columns in row ' .. options.rowOffset + lineNum)
end
end
return outResults, i, totalColumnCount
end
local function handleHeaders(headerField, options)
if options.headers == false then
for j = 1, #headerField do
headerField[j] = j
end
else
for _, headerName in ipairs(headerField) do
if #headerName == 0 then
error('ftcsv: Cannot parse a file which contains empty headers')
end
end
end
if options.rename then
for j = 1, #headerField do
if options.rename[headerField[j]] then
headerField[j] = options.rename[headerField[j]]
end
end
if #options.rename > 0 then
for j = 1, #options.rename do
headerField[j] = options.rename[j]
end
end
end
if options.headerFunc then
for j = 1, #headerField do
headerField[j] = options.headerFunc(headerField[j])
end
end
return headerField
end
local function loadFile(textFile, amount)
local file = io.open(textFile, "r")
if not file then error("ftcsv: File not found at " .. textFile) end
local lines = file:read(amount)
if amount == "*all" then
file:close()
end
return lines, file
end
local function initializeInputFromStringOrFile(inputFile, options, amount)
local inputString, file
if options.loadFromString then
inputString = inputFile
else
inputString, file = loadFile(inputFile, amount)
end
if inputString == "" then
error('ftcsv: Cannot parse an empty file')
end
return inputString, file
end
local function determineArgumentOrder(delimiter, options)
if type(delimiter) == "string" then
return delimiter, options
elseif type(delimiter) == "table" then
local realDelimiter = delimiter.delimiter or ","
return realDelimiter, delimiter
else
return ",", nil
end
end
local function parseOptions(delimiter, options, fromParseLine)
assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")
local fieldsToKeep = nil
if options then
if options.headers ~= nil then
assert(type(options.headers) == "boolean", "ftcsv only takes the boolean 'true' or 'false' for the optional parameter 'headers' (default 'true'). You passed in '" .. tostring(options.headers) .. "' of type '" .. type(options.headers) .. "'.")
end
if options.rename ~= nil then
assert(type(options.rename) == "table", "ftcsv only takes in a key-value table for the optional parameter 'rename'. You passed in '" .. tostring(options.rename) .. "' of type '" .. type(options.rename) .. "'.")
end
if options.fieldsToKeep ~= nil then
assert(type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.fieldsToKeep) .. "' of type '" .. type(options.fieldsToKeep) .. "'.")
local ofieldsToKeep = options.fieldsToKeep
if ofieldsToKeep ~= nil then
fieldsToKeep = {}
for j = 1, #ofieldsToKeep do
fieldsToKeep[ofieldsToKeep[j]] = true
end
end
if options.headers == false and options.rename == nil then
error("ftcsv: fieldsToKeep only works with header-less files when using the 'rename' functionality")
end
end
if options.loadFromString ~= nil then
assert(type(options.loadFromString) == "boolean", "ftcsv only takes a boolean value for optional parameter 'loadFromString'. You passed in '" .. tostring(options.loadFromString) .. "' of type '" .. type(options.loadFromString) .. "'.")
end
if options.headerFunc ~= nil then
assert(type(options.headerFunc) == "function", "ftcsv only takes a function value for optional parameter 'headerFunc'. You passed in '" .. tostring(options.headerFunc) .. "' of type '" .. type(options.headerFunc) .. "'.")
end
if options.ignoreQuotes == nil then
options.ignoreQuotes = false
else
assert(type(options.ignoreQuotes) == "boolean", "ftcsv only takes a boolean value for optional parameter 'ignoreQuotes'. You passed in '" .. tostring(options.ignoreQuotes) .. "' of type '" .. type(options.ignoreQuotes) .. "'.")
end
if fromParseLine == true then
if options.bufferSize == nil then
options.bufferSize = 2^16
else
assert(type(options.bufferSize) == "number", "ftcsv only takes a number value for optional parameter 'bufferSize'. You passed in '" .. tostring(options.bufferSize) .. "' of type '" .. type(options.bufferSize) .. "'.")
end
else
if options.bufferSize ~= nil then
error("ftcsv: bufferSize can only be specified using 'parseLine'. When using 'parse', the entire file is read into memory")
end
end
else
options = {
["headers"] = true,
["loadFromString"] = false,
["ignoreQuotes"] = false,
["bufferSize"] = 2^16
}
end
return options, fieldsToKeep
end
local function findEndOfHeaders(str, entireFile)
local i = 1
local quote = sbyte('"')
local newlines = {
[sbyte("\n")] = true,
[sbyte("\r")] = true
}
local quoted = false
local char = sbyte(str, i)
repeat
if char == quote then
quoted = not quoted
end
i = i + 1
char = sbyte(str, i)
until (newlines[char] and not quoted) or char == nil
if not entireFile and char == nil then
error("ftcsv: bufferSize needs to be larger to parse this file")
end
local nextChar = sbyte(str, i+1)
if nextChar == sbyte("\n") and char == sbyte("\r") then
i = i + 1
end
return i
end
local function determineBOMOffset(inputString)
if sbyte(inputString, 1) == 239
and sbyte(inputString, 2) == 187
and sbyte(inputString, 3) == 191 then
return 4
else
return 1
end
end
local function parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep, entireFile)
local startLine = determineBOMOffset(inputString)
local endOfHeaderRow = findEndOfHeaders(inputString, entireFile)
local parserArgs = {
delimiter = delimiter,
headerField = nil,
fieldsToKeep = nil,
inputLength = endOfHeaderRow,
buffered = false,
ignoreQuotes = options.ignoreQuotes,
rowOffset = 0
}
local rawHeaders, endOfHeaders = parseString(inputString, startLine, parserArgs)
local modifiedHeaders = handleHeaders(rawHeaders[1], options)
parserArgs.headerField = modifiedHeaders
parserArgs.fieldsToKeep = fieldsToKeep
parserArgs.inputLength = nil
if options.headers == false then endOfHeaders = startLine end
local finalHeaders = determineRealHeaders(modifiedHeaders, fieldsToKeep)
if options.headers ~= false then
local headersMetamethod = generateHeadersMetamethod(finalHeaders)
parserArgs.headersMetamethod = headersMetamethod
end
return endOfHeaders, parserArgs, finalHeaders
end
function ftcsv.parse(inputFile, delimiter, options)
local delimiter, options = determineArgumentOrder(delimiter, options)
local options, fieldsToKeep = parseOptions(delimiter, options, false)
local inputString = initializeInputFromStringOrFile(inputFile, options, "*all")
local endOfHeaders, parserArgs, finalHeaders = parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep, true)
local output = parseString(inputString, endOfHeaders, parserArgs)
return output, finalHeaders
end
local function getFileSize (file)
local current = file:seek()
local size = file:seek("end")
file:seek("set", current)
return size
end
local function determineAtEndOfFile(file, fileSize)
if file:seek() >= fileSize then
return true
else
return false
end
end
local function initializeInputFile(inputString, options)
if options.loadFromString == true then
error("ftcsv: parseLine currently doesn't support loading from string")
end
return initializeInputFromStringOrFile(inputString, options, options.bufferSize)
end
function ftcsv.parseLine(inputFile, delimiter, userOptions)
local delimiter, userOptions = determineArgumentOrder(delimiter, userOptions)
local options, fieldsToKeep = parseOptions(delimiter, userOptions, true)
local inputString, file = initializeInputFile(inputFile, options)
local fileSize, atEndOfFile = 0, false
fileSize = getFileSize(file)
atEndOfFile = determineAtEndOfFile(file, fileSize)
local endOfHeaders, parserArgs, _ = parseHeadersAndSetupArgs(inputString, delimiter, options, fieldsToKeep, atEndOfFile)
parserArgs.buffered = true
parserArgs.endOfFile = atEndOfFile
local parsedBuffer, endOfParsedInput, totalColumnCount = parseString(inputString, endOfHeaders, parserArgs)
parserArgs.totalColumnCount = totalColumnCount
inputString = ssub(inputString, endOfParsedInput)
local bufferIndex, returnedRowsCount = 0, 0
local currentRow, buffer
return function()
bufferIndex = bufferIndex + 1
currentRow = parsedBuffer[bufferIndex]
if currentRow then
returnedRowsCount = returnedRowsCount + 1
return returnedRowsCount, currentRow
end
buffer = file:read(options.bufferSize)
if not buffer then
file:close()
return nil
else
parserArgs.endOfFile = determineAtEndOfFile(file, fileSize)
end
inputString = inputString .. buffer
parserArgs.rowOffset = returnedRowsCount
parsedBuffer, endOfParsedInput = parseString(inputString, 1, parserArgs)
bufferIndex = 1
inputString = ssub(inputString, endOfParsedInput)
if #parsedBuffer == 0 then
error("ftcsv: bufferSize needs to be larger to parse this file")
end
returnedRowsCount = returnedRowsCount + 1
return returnedRowsCount, parsedBuffer[bufferIndex]
end
end
local function generateCustomToString(valueToConvertNilTo)
local newReturnValue = tostring(valueToConvertNilTo)
local generatedFunction = function(field)
if type(field) == "nil" then
return newReturnValue
else
return tostring(field)
end
end
return generatedFunction
end
local function generateDelimitField(customToString)
local delimitField = function(field)
field = customToString(field)
if field:find('"') then
return field:gsub('"', '""')
else
return field
end
end
return delimitField
end
local function generateDelimitAndQuoteField(delimiter, customToString)
local generatedFunction = function(field)
field = customToString(field)
if field:find('"') then
return '"' .. field:gsub('"', '""') .. '"'
elseif field:find('[\n' .. delimiter .. ']') then
return '"' .. field .. '"'
else
return field
end
end
return generatedFunction
end
local function escapeHeadersForLuaGenerator(headers)
local escapedHeaders = {}
for i = 1, #headers do
if headers[i]:find('"') then
escapedHeaders[i] = headers[i]:gsub('"', '\\"')
else
escapedHeaders[i] = headers[i]
end
end
return escapedHeaders
end
local function csvLineGenerator(inputTable, delimiter, headers, options)
local escapedHeaders = escapeHeadersForLuaGenerator(headers)
local outputFunc = [[
local args, i = ...
i = i + 1;
if i > ]] .. #inputTable .. [[ then return nil end;
return i, '"' .. args.delimitField(args.t[i]["]] ..
table.concat(escapedHeaders, [["]) .. '"]] ..
delimiter .. [["' .. args.delimitField(args.t[i]["]]) ..
[["]) .. '"\r\n']]
if options and options.onlyRequiredQuotes == true then
outputFunc = [[
local args, i = ...
i = i + 1;
if i > ]] .. #inputTable .. [[ then return nil end;
return i, args.delimitField(args.t[i]["]] ..
table.concat(escapedHeaders, [["]) .. ']] ..
delimiter .. [[' .. args.delimitField(args.t[i]["]]) ..
[["]) .. '\r\n']]
end
local arguments = {}
arguments.t = inputTable
local toStringToUse = tostring
if options and options.encodeNilAs ~= nil then
toStringToUse = generateCustomToString(options.encodeNilAs)
end
if options and options.onlyRequiredQuotes == true then
arguments.delimitField = generateDelimitAndQuoteField(delimiter, toStringToUse)
else
arguments.delimitField = generateDelimitField(toStringToUse)
end
return luaCompatibility.load(outputFunc), arguments, 0
end
local function validateHeaders(headers, inputTable)
for i = 1, #headers do
if inputTable[1][headers[i]] == nil then
error("ftcsv: the field '" .. headers[i] .. "' doesn't exist in the inputTable")
end
end
end
local function initializeOutputWithEscapedHeaders(escapedHeaders, delimiter, options)
local output = {}
if options and options.onlyRequiredQuotes == true then
output[1] = table.concat(escapedHeaders, delimiter) .. '\r\n'
else
output[1] = '"' .. table.concat(escapedHeaders, '"' .. delimiter .. '"') .. '"\r\n'
end
return output
end
local function escapeHeadersForOutput(headers, delimiter, options)
local escapedHeaders = {}
local delimitField = generateDelimitField(tostring)
if options and options.onlyRequiredQuotes == true then
delimitField = generateDelimitAndQuoteField(delimiter, tostring)
end
for i = 1, #headers do
escapedHeaders[i] = delimitField(headers[i])
end
return escapedHeaders
end
local function extractHeadersFromTable(inputTable)
local headers = {}
for key, _ in pairs(inputTable[1]) do
headers[#headers+1] = key
end
table.sort(headers)
return headers
end
local function getHeadersFromOptions(options)
local headers = nil
if options then
if options.fieldsToKeep ~= nil then
assert(
type(options.fieldsToKeep) == "table", "ftcsv only takes in a list (as a table) for the optional parameter 'fieldsToKeep'. You passed in '" .. tostring(options.headers) .. "' of type '" .. type(options.headers) .. "'.")
headers = options.fieldsToKeep
end
end
return headers
end
local function initializeGenerator(inputTable, delimiter, options)
assert(#delimiter == 1 and type(delimiter) == "string", "the delimiter must be of string type and exactly one character")
local headers = getHeadersFromOptions(options)
if headers == nil then
headers = extractHeadersFromTable(inputTable)
end
validateHeaders(headers, inputTable)
local escapedHeaders = escapeHeadersForOutput(headers, delimiter, options)
local output = initializeOutputWithEscapedHeaders(escapedHeaders, delimiter, options)
return output, headers
end
function ftcsv.encode(inputTable, delimiter, options)
local delimiter, options = determineArgumentOrder(delimiter, options)
local output, headers = initializeGenerator(inputTable, delimiter, options)
for i, line in csvLineGenerator(inputTable, delimiter, headers, options) do
output[i+1] = line
end
return table.concat(output)
end
return ftcsv
end
return m58c629bdadd0()
