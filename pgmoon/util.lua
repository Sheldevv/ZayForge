-- pgmoon util.lua — patched for Love2D
-- Base64 fallback: tries mime (from luasocket), falls back to pure-Lua

local flatten
do
  local __flatten
  __flatten = function(t, buffer)
    local _exp_0 = type(t)
    if "string" == _exp_0 then
      buffer[#buffer + 1] = t
    elseif "number" == _exp_0 then
      buffer[#buffer + 1] = tostring(t)
    elseif "table" == _exp_0 then
      for _index_0 = 1, #t do
        local thing = t[_index_0]
        __flatten(thing, buffer)
      end
    end
  end
  flatten = function(t)
    local buffer = { }
    __flatten(t, buffer)
    return table.concat(buffer)
  end
end

local encode_base64, decode_base64
if ngx then
  do
    local _obj_0 = ngx
    encode_base64, decode_base64 = _obj_0.encode_base64, _obj_0.decode_base64
  end
else
  -- Try luasocket's mime module first
  local has_mime = pcall(function() return require("mime") end)
  if has_mime then
    local _obj_0 = require("mime")
    local b64, unb64 = _obj_0.b64, _obj_0.unb64
    encode_base64 = function(...) return (b64(...)) end
    decode_base64 = function(...) return (unb64(...)) end
  else
    -- Fallback to pure-Lua base64
    local fallback = require("pgmoon.pgmoon_crypto_fallback")
    encode_base64 = function(str)
      -- pgmoon only calls decode_base64; encode rarely needed. Use fallback.
      -- Simple base64 encode
      local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
      local result = {}
      local padding = (3 - (#str % 3)) % 3
      str = str .. string.rep("\0", padding)
      for i = 1, #str, 3 do
        local a, b, c = str:byte(i, i + 2)
        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        result[#result + 1] = b64chars:sub(c1 + 1, c1 + 1)
        result[#result + 1] = b64chars:sub(c2 + 1, c2 + 1)
        result[#result + 1] = b64chars:sub(c3 + 1, c3 + 1)
        result[#result + 1] = b64chars:sub(c4 + 1, c4 + 1)
      end
      if padding > 0 then
        result[#result] = "="
        if padding > 1 then result[#result - 1] = "=" end
      end
      return table.concat(result)
    end
    decode_base64 = function(str)
      return fallback.decode_base64(str)
    end
  end
end

return {
  flatten = flatten,
  encode_base64 = encode_base64,
  decode_base64 = decode_base64
}
