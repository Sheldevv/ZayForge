-- pgmoon crypto.lua — patched for Love2D
-- Original tries: ngx / openssl.* / LuaCrypto / resty.*
-- Patched to fall back to pgmoon_crypto_fallback (pure Lua) when none exist.

local fallback

local function get_fallback()
  if not fallback then
    fallback = require("pgmoon.pgmoon_crypto_fallback")
  end
  return fallback
end

-- md5
local md5
if ngx then
  md5 = ngx.md5
elseif pcall(function() return require("openssl.digest") end) then
  local openssl_digest = require("openssl.digest")
  local hex_char = function(c) return string.format("%02x", string.byte(c)) end
  local hex = function(str) return (str:gsub(".", hex_char)) end
  md5 = function(str) return hex(openssl_digest.new("md5"):final(str)) end
elseif pcall(function() return require("crypto") end) then
  local crypto = require("crypto")
  md5 = function(str) return crypto.digest("md5", str) end
else
  md5 = function(str) return get_fallback().md5(str) end
end

-- hmac_sha256
local hmac_sha256
if pcall(function() return require("openssl.hmac") end) then
  hmac_sha256 = function(key, str)
    local openssl_hmac = require("openssl.hmac")
    local hmac = assert(openssl_hmac.new(key, "sha256"))
    hmac:update(str)
    return assert(hmac:final())
  end
elseif pcall(function() return require("resty.openssl.hmac") end) then
  hmac_sha256 = function(key, str)
    local openssl_hmac = require("resty.openssl.hmac")
    local hmac = assert(openssl_hmac.new(key, "sha256"))
    hmac:update(str)
    return assert(hmac:final())
  end
else
  hmac_sha256 = function(key, str) return get_fallback().hmac_sha256(key, str) end
end

-- digest_sha256
local digest_sha256
if pcall(function() return require("openssl.digest") end) then
  digest_sha256 = function(str)
    local digest = assert(require("openssl.digest").new("sha256"))
    digest:update(str)
    return assert(digest:final())
  end
elseif pcall(function() return require("resty.sha256") end) then
  digest_sha256 = function(str)
    local digest = assert(require("resty.sha256"):new())
    digest:update(str)
    return assert(digest:final())
  end
elseif pcall(function() return require("resty.openssl.digest") end) then
  digest_sha256 = function(str)
    local digest = assert(require("resty.openssl.digest").new("sha256"))
    digest:update(str)
    return assert(digest:final())
  end
else
  digest_sha256 = function(str) return get_fallback().digest_sha256(str) end
end

-- kdf_derive_sha256 (PBKDF2)
local kdf_derive_sha256
if pcall(function() return require("openssl.kdf") end) then
  kdf_derive_sha256 = function(str, salt, i)
    local openssl_kdf = require("openssl.kdf")
    local decode_base64 = require("pgmoon.util").decode_base64
    salt = decode_base64(salt)
    local key, err = openssl_kdf.derive({
      type = "PBKDF2", md = "sha256", salt = salt, iter = i, pass = str, outlen = 32
    })
    if not key then return nil, "failed to derive pbkdf2 key: " .. tostring(err) end
    return key
  end
elseif pcall(function() return require("resty.openssl.kdf") end) then
  kdf_derive_sha256 = function(str, salt, i)
    local openssl_kdf = require("resty.openssl.kdf")
    local decode_base64 = require("pgmoon.util").decode_base64
    salt = decode_base64(salt)
    local key, err = openssl_kdf.derive({
      type = openssl_kdf.PBKDF2, md = "sha256", salt = salt,
      pbkdf2_iter = i, pass = str, outlen = 32
    })
    if not key then return nil, "failed to derive pbkdf2 key: " .. tostring(err) end
    return key
  end
else
  kdf_derive_sha256 = function(str, salt, i)
    return get_fallback().kdf_derive_sha256(str, salt, i)
  end
end

-- random_bytes
local random_bytes
if pcall(function() return require("openssl.rand") end) then
  random_bytes = require("openssl.rand").bytes
elseif pcall(function() return require("resty.random") end) then
  random_bytes = require("resty.random").bytes
elseif pcall(function() return require("resty.openssl.rand") end) then
  random_bytes = require("resty.openssl.rand").bytes
else
  random_bytes = function(n) return get_fallback().random_bytes(n) end
end

-- x509_digest — computes sha256 of DER certificate bytes for channel binding
local x509_digest
if pcall(function() return require("openssl.x509") end) then
  local x509 = require("openssl.x509")
  x509_digest = function(pem, hash_type)
    return x509.new(pem, "PEM"):digest(hash_type, "s")
  end
elseif pcall(function() return require("resty.openssl.x509") end) then
  local x509 = require("resty.openssl.x509")
  x509_digest = function(pem, hash_type)
    return x509.new(pem, "PEM"):digest(hash_type)
  end
else
  -- Pure-Lua fallback: decode PEM to DER bytes, hash with SHA-256
  x509_digest = function(pem, hash_type)
    local fb = get_fallback()
    -- Strip PEM headers/footers and whitespace, leaving pure base64
    local b64 = pem:gsub("%-%-%-%-%-BEGIN .-%-%-%-%-%-", "")
    b64 = b64:gsub("%-%-%-%-%-END .-%-%-%-%-%-", "")
    b64 = b64:gsub("[%s]", "")
    if #b64 == 0 then
      return nil, "invalid PEM certificate"
    end
    local der_bytes = fb.decode_base64(b64)
    if hash_type == "sha256" then
      return fb.digest_sha256(der_bytes)
    else
      return nil, "unsupported hash type: " .. tostring(hash_type)
    end
  end
end

return {
  md5 = md5,
  hmac_sha256 = hmac_sha256,
  digest_sha256 = digest_sha256,
  kdf_derive_sha256 = kdf_derive_sha256,
  random_bytes = random_bytes,
  x509_digest = x509_digest
}
