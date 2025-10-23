local function is_identifier(s)
  return type(s) == "string" and s:match("^[A-Za-z_][A-Za-z0-9_]*$") ~= nil
end

local function escape_string_single(s)
  local out = {}
  for i = 1, #s do
    local c = s:sub(i,i)
    local b = string.byte(c)
    if c == "\\" then
      out[#out+1] = "\\\\"
    elseif c == "'" then
      out[#out+1] = "\\'"
    elseif c == "\n" then
      out[#out+1] = "\\n"
    elseif c == "\r" then
      out[#out+1] = "\\r"
    elseif c == "\t" then
      out[#out+1] = "\\t"
    elseif b >= 32 and b <= 126 then
      out[#out+1] = c
    else
      out[#out+1] = string.format("\\%03d", b)
    end
  end
  return "'" .. table.concat(out) .. "'"
end

local function escape_string_all(s)
  local out = {}
  for i = 1, #s do
    out[#out+1] = string.format("\\%03d", string.byte(s, i))
  end
  return "'" .. table.concat(out) .. "'"
end

local function table_keys(t)
  local keys = {}
  for k in pairs(t) do
    keys[#keys+1] = k
  end
  table.sort(keys, function(a,b)
    local ta, tb = type(a), type(b)
    if ta == tb then
      if ta == "number" then return a < b end
      return tostring(a) < tostring(b)
    end
    return ta < tb
  end)
  return keys
end

local function key_to_literal(k, escaper)
  local kt = type(k)
  if kt == "string" then
    if is_identifier(k) then
      return k, true
    else
      return "[" .. escaper(k) .. "]", false
    end
  elseif kt == "number" then
    return "[" .. tostring(k) .. "]", false
  else
    -- other key types (boolean/table/function/thread/userdata) -> stringify them as ['type:...']
    return "[" .. escaper(tostring(k)) .. "]", false
  end
end

local function serialize_no_recursion(root, escaper)
  if type(root) ~= "table" then
    return "return nil"
  end

  local out = {} -- array of string parts; for table placeholders we will manage insertion
  local seen = {} -- table -> true when we've pushed it to be serialized
  local stack = {} -- frames: { tbl=..., keys=..., idx=..., started=bool, out_pos = <position in out> }

  -- push root frame
  seen[root] = true
  stack[#stack+1] = { tbl = root, keys = nil, idx = 1, started = false, out_pos = #out + 1 }
  out[#out+1] = nil -- placeholder for root table text

  while #stack > 0 do
    local frame = stack[#stack]
    local tbl = frame.tbl

    if not frame.started then
      frame.keys = table_keys(tbl)
      frame.idx = 1
      frame.started = true
      -- start table text
      local startpos = #out + 1
      out[#out+1] = "{"
      frame.out_pos = startpos
    end

    if frame.idx > #frame.keys then
      -- finish table
      out[#out+1] = "}"
      stack[#stack] = nil
      -- if there is still a parent waiting where a placeholder nil exists right before where we pushed child,
      -- we leave placeholders as-is because we inserted child text directly into out sequence.
    else
      -- process next key/value
      local k = frame.keys[frame.idx]
      local v = tbl[k]
      frame.idx = frame.idx + 1

      -- skip values that are functions/threads/userdata/metatable weirdness
      local vt = type(v)
      if vt == "function" or vt == "thread" or vt == "userdata" then
        -- skip entirely
      else
        -- add separator if not first element
        if frame.idx > 2 then
          out[#out+1] = ", "
        end

        -- key literal
        local keylit, isbare = key_to_literal(k, escaper)
        if isbare then
          out[#out+1] = keylit
          out[#out+1] = "="
        else
          out[#out+1] = keylit
          out[#out+1] = " = "
        end

        -- value literal or nested table push
        if vt == "table" then
          if seen[v] then
            out[#out+1] = "nil" -- circular
          else
            -- push placeholder and child frame: but we will continue loop, so simply push child frame and mark seen.
            seen[v] = true
            -- push child frame; but before that, we don't insert placeholder because child will insert its own "{" directly.
            stack[#stack+1] = { tbl = v, keys = nil, idx = 1, started = false, out_pos = #out + 1 }
            out[#out+1] = nil -- placeholder position where child's "{" will be placed next iteration
          end
        else
          -- primitive -> append literal
          if vt == "string" then
            out[#out+1] = escaper(v)
          elseif vt == "number" then
            out[#out+1] = tostring(v)
          elseif vt == "boolean" then
            out[#out+1] = v and "true" or "false"
          elseif vt == "nil" then
            out[#out+1] = "nil"
          else
            -- anything else (shouldn't happen) -> tostring
            out[#out+1] = escaper(tostring(v))
          end
        end
      end
    end
  end

  -- join and return with leading "return "
  return "return " .. table.concat(out)
end

local function encode(tbl)
  return serialize_no_recursion(tbl, escape_string_single)
end

local function safe_encode(tbl)
  return serialize_no_recursion(tbl, escape_string_all)
end


return {
    encode = encode,
    safe_encode = safe_encode
}
