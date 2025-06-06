local b64_chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local b64_table = {}
for i = 1, #b64_chars do
  b64_table[b64_chars:sub(i, i)] = i - 1
end

local function base64_encode(input)
  local output = ""
  local padding = 0
  local len = #input
  for i = 1, len, 3 do
    local a, b, c = string.byte(input, i, i + 2)
    if not c then
      padding = 3 - (i - 1) % 3
      a, b = a or 0, b or 0
      c = 0
    end
    output = output .. b64_chars:sub(math.floor(a / 4) + 1, math.floor(a / 4) + 1)
    output = output .. b64_chars:sub(((a % 4) * 16) + math.floor(b / 16) + 1, ((a % 4) * 16) + math.floor(b / 16) + 1)
    output = output .. b64_chars:sub(((b % 16) * 4) + math.floor(c / 64) + 1, ((b % 16) * 4) + math.floor(c / 64) + 1)
    output = output .. b64_chars:sub(c % 64 + 1, c % 64 + 1)
  end
  
  if padding > 0 then
    for i = 1, padding do
      output = output:sub(1, -2) .. '='
    end
  end
  
  return output
end

local function base64_decode(input)
  local output = ""
  local padding = 0
  local len = #input
  
  if input:sub(len-1) == "=" then
    padding = 2
    input = input:sub(1, len-2)
  elseif input:sub(len) == "=" then
    padding = 1
    input = input:sub(1, len-1)
  end
  
  for i = 1, #input, 4 do
    local a, b, c, d = string.byte(input, i, i + 3)
    if a then a = b64_table[string.char(a)] or 0 end
    if b then b = b64_table[string.char(b)] or 0 end
    if c then c = b64_table[string.char(c)] or 0 end
    if d then d = b64_table[string.char(d)] or 0 end
    
    output = output .. string.char((a * 4) + math.floor(b / 16))
    output = output .. string.char(((b % 16) * 16) + math.floor(c / 4))
    if padding < 2 then
      output = output .. string.char(((c % 4) * 64) + d)
    end
  end
  
  return output
end

local P = {
  decode = base64_decode,
  encode = base64_encode
}

return P
