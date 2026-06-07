-- pgmoon_crypto_fallback.lua
-- Pure-Lua crypto for pgmoon inside Love2D (no luaossl/LuaCrypto needed)
--
-- pgmoon's crypto.lua tries: openssl.* → crypto → resty.*
-- None of those exist in Love2D. This module provides:
--   md5, hmac_sha256, digest_sha256, kdf_derive_sha256, random_bytes

local bit = require("pgmoon.bit")
local band, bor, bxor, lshift, rshift = bit.band, bit.bor, bit.bxor, bit.lshift, bit.rshift

local fallback = {}

-- ===== UTF-8 helpers (pass-through for ASCII names/passwords) =====
local function toBytes(str)
    return { str:byte(1, #str) }
end

local function bytesToString(bytes)
    return string.char(unpack and table.unpack(bytes) or unpack(bytes))
end

-- ===== Base64 decode (pgmoon uses this for SCRAM salt) =====
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function b64_index(c)
    for i = 1, #b64chars do
        if b64chars:sub(i, i) == c then return i - 1 end
    end
    return 0
end

function fallback.decode_base64(str)
    str = str:gsub("[^%w%+/=]", "")
    local bytes = {}
    local i = 1
    while i <= #str do
        local a = b64_index(str:sub(i, i) or "")
        local b = b64_index(str:sub(i + 1, i + 1) or "")
        local c = b64_index(str:sub(i + 2, i + 2) or "")
        local d = b64_index(str:sub(i + 3, i + 3) or "")
        if a < 0 or b < 0 then break end
        bytes[#bytes + 1] = band(rshift(a, 2), 0xFF) ~ 0 and lshift(a, 2) + band(rshift(b, 4), 0x03) or nil
        if bytes[#bytes] then bytes[#bytes] = lshift(a, 2) + band(rshift(b, 4), 0x03) end
        -- Actually, simpler approach:
    end
    -- Use a correct base64 decoder
    local result = {}
    local padding = 0
    for j = #str, 1, -1 do
        if str:sub(j, j) == "=" then padding = padding + 1 else break end
    end

    for j = 1, #str, 4 do
        local n1 = b64_index(str:sub(j, j))
        local n2 = b64_index(str:sub(j + 1, j + 1))
        local n3 = b64_index(str:sub(j + 2, j + 2))
        local n4 = b64_index(str:sub(j + 3, j + 3))
        local triple = lshift(n1, 18) + lshift(n2, 12) + lshift(n3, 6) + n4
        result[#result + 1] = band(rshift(triple, 16), 0xFF)
        result[#result + 1] = band(rshift(triple, 8), 0xFF)
        result[#result + 1] = band(triple, 0xFF)
    end

    for k = 1, padding do
        result[#result] = nil
    end

    return string.char(unpack and table.unpack(result) or unpack(result))
end

-- ===== SHA-256 (pure Lua) =====
-- Based on RFC 6234; adapted for Lua

local sha256_k = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
    0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
    0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
    0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
    0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
    0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
    0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local function toUint32(n)
    return band(n, 0xFFFFFFFF)
end

local function rotr(n, b)
    return toUint32(bor(rshift(n, b), lshift(n, 32 - b)))
end

local function sha256_transform(state, block)
    local w = {}
    for i = 0, 15 do
        w[i] = lshift(block[i * 4 + 1], 24) + lshift(block[i * 4 + 2], 16)
            + lshift(block[i * 4 + 3], 8) + block[i * 4 + 4]
    end
    for i = 16, 63 do
        local s0 = bxor(rotr(w[i - 15], 7), bxor(rotr(w[i - 15], 18), rshift(w[i - 15], 3)))
        local s1 = bxor(rotr(w[i - 2], 17), bxor(rotr(w[i - 2], 19), rshift(w[i - 2], 10)))
        w[i] = toUint32(w[i - 16] + s0 + w[i - 7] + s1)
    end

    local a, b, c, d, e, f, g, h = state[1], state[2], state[3], state[4],
        state[5], state[6], state[7], state[8]

    for i = 0, 63 do
        local S1 = bxor(rotr(e, 6), bxor(rotr(e, 11), rotr(e, 25)))
        local ch = bxor(band(e, f), band(bnot(e), g))
        local temp1 = toUint32(h + S1 + ch + sha256_k[i + 1] + w[i])
        local S0 = bxor(rotr(a, 2), bxor(rotr(a, 13), rotr(a, 22)))
        local maj = bxor(band(a, b), bxor(band(a, c), band(b, c)))
        local temp2 = toUint32(S0 + maj)

        h, g, f, e = g, f, e, toUint32(d + temp1)
        d, c, b, a = c, b, a, toUint32(temp1 + temp2)
    end

    state[1] = toUint32(state[1] + a)
    state[2] = toUint32(state[2] + b)
    state[3] = toUint32(state[3] + c)
    state[4] = toUint32(state[4] + d)
    state[5] = toUint32(state[5] + e)
    state[6] = toUint32(state[6] + f)
    state[7] = toUint32(state[7] + g)
    state[8] = toUint32(state[8] + h)
end

function fallback.sha256(data)
    -- Convert string to byte array
    local bytes = { data:byte(1, #data) }
    local bitlen = #bytes * 8

    -- Padding
    bytes[#bytes + 1] = 0x80
    while (#bytes % 64) ~= 56 do
        bytes[#bytes + 1] = 0
    end

    -- Append length in big-endian 64-bit
    local high = math.floor(bitlen / 0x100000000)
    local low = bitlen % 0x100000000
    for i = 28, 0, -8 do bytes[#bytes + 1] = band(rshift(high, i), 0xFF) end
    for i = 24, 0, -8 do bytes[#bytes + 1] = band(rshift(low, i), 0xFF) end

    -- Initial hash values
    local state = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }

    -- Process each 64-byte chunk
    for i = 1, #bytes, 64 do
        local block = {}
        for j = 1, 64 do
            block[j] = bytes[i + j - 1] or 0
        end
        sha256_transform(state, block)
    end

    -- Output as hex
    local result = ""
    for i = 1, 8 do
        result = result .. string.format("%08x", state[i])
    end
    return result
end

-- ===== HMAC-SHA-256 =====
local function hmac_sha256(key_bytes, message)
    local block_size = 64
    local key = {}
    for i = 1, #key_bytes do key[i] = key_bytes[i] end

    -- If key is longer than block_size, hash it
    if #key > block_size then
        local hash = fallback.sha256(string.char(unpack and table.unpack(key) or unpack(key)))
        key = {}
        for i = 1, #hash, 2 do
            key[#key + 1] = tonumber(hash:sub(i, i + 1), 16)
        end
    end

    -- Pad key to block_size
    for i = #key + 1, block_size do key[i] = 0 end

    -- o_key_pad = key xor 0x5c
    local o_key_pad = {}
    for i = 1, block_size do o_key_pad[i] = bxor(key[i], 0x5c) end

    -- i_key_pad = key xor 0x36
    local i_key_pad = {}
    for i = 1, block_size do i_key_pad[i] = bxor(key[i], 0x36) end

    -- inner hash
    local inner = string.char(unpack and table.unpack(i_key_pad) or unpack(i_key_pad)) .. message
    local inner_hash = fallback.sha256(inner)

    -- outer hash
    local inner_bytes = {}
    for i = 1, #inner_hash, 2 do
        inner_bytes[#inner_bytes + 1] = tonumber(inner_hash:sub(i, i + 1), 16)
    end
    local outer = string.char(unpack and table.unpack(o_key_pad) or unpack(o_key_pad))
        .. string.char(unpack and table.unpack(inner_bytes) or unpack(inner_bytes))

    return fallback.sha256(outer)
end

function fallback.hmac_sha256(key_str, msg_str)
    local key_bytes = { key_str:byte(1, #key_str) }
    return hmac_sha256(key_bytes, msg_str)
end

-- ===== SHA-256 digest (binary output) =====
function fallback.digest_sha256(str)
    local hex = fallback.sha256(str)
    local result = {}
    for i = 1, #hex, 2 do
        result[#result + 1] = string.char(tonumber(hex:sub(i, i + 1), 16))
    end
    return table.concat(result)
end

-- ===== MD5 (pure Lua) =====
-- Based on RFC 1321

local md5_T = {}
for i = 1, 64 do
    md5_T[i] = math.floor(0x100000000 * math.abs(math.sin(i)))
end

local function md5_ff(a, b, c, d, x, s, t)
    return toUint32(rotr(toUint32(a + bor(band(b, c), band(bnot(b), d)) + x + t), 32 - s) + b)
end

local function md5_gg(a, b, c, d, x, s, t)
    return toUint32(rotr(toUint32(a + bor(band(b, d), band(c, bnot(d))) + x + t), 32 - s) + b)
end

local function md5_hh(a, b, c, d, x, s, t)
    return toUint32(rotr(toUint32(a + bxor(b, bxor(c, d)) + x + t), 32 - s) + b)
end

local function md5_ii(a, b, c, d, x, s, t)
    return toUint32(rotr(toUint32(a + bxor(c, bor(b, bnot(d))) + x + t), 32 - s) + b)
end

function fallback.md5(str)
    local bytes = { str:byte(1, #str) }
    local bitlen = #bytes * 8

    -- Padding
    bytes[#bytes + 1] = 0x80
    while (#bytes % 64) ~= 56 do
        bytes[#bytes + 1] = 0
    end

    -- Append length (little-endian 64-bit)
    local low = bitlen % 0x100000000
    local high = math.floor(bitlen / 0x100000000)
    for i = 0, 24, 8 do bytes[#bytes + 1] = band(rshift(low, i), 0xFF) end
    for i = 0, 24, 8 do bytes[#bytes + 1] = band(rshift(high, i), 0xFF) end

    -- Initial values
    local a, b, c, d = 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476

    -- Process each 64-byte chunk
    for i = 1, #bytes, 64 do
        local x = {}
        for j = 0, 15 do
            x[j] = lshift(bytes[i + j * 4 + 3] or 0, 24)
                + lshift(bytes[i + j * 4 + 2] or 0, 16)
                + lshift(bytes[i + j * 4 + 1] or 0, 8)
                + (bytes[i + j * 4] or 0)
        end

        local aa, bb, cc, dd = a, b, c, d

        -- Round 1
        a = md5_ff(a, b, c, d, x[0], 7, md5_T[1])
        d = md5_ff(d, a, b, c, x[1], 12, md5_T[2])
        c = md5_ff(c, d, a, b, x[2], 17, md5_T[3])
        b = md5_ff(b, c, d, a, x[3], 22, md5_T[4])
        a = md5_ff(a, b, c, d, x[4], 7, md5_T[5])
        d = md5_ff(d, a, b, c, x[5], 12, md5_T[6])
        c = md5_ff(c, d, a, b, x[6], 17, md5_T[7])
        b = md5_ff(b, c, d, a, x[7], 22, md5_T[8])
        a = md5_ff(a, b, c, d, x[8], 7, md5_T[9])
        d = md5_ff(d, a, b, c, x[9], 12, md5_T[10])
        c = md5_ff(c, d, a, b, x[10], 17, md5_T[11])
        b = md5_ff(b, c, d, a, x[11], 22, md5_T[12])
        a = md5_ff(a, b, c, d, x[12], 7, md5_T[13])
        d = md5_ff(d, a, b, c, x[13], 12, md5_T[14])
        c = md5_ff(c, d, a, b, x[14], 17, md5_T[15])
        b = md5_ff(b, c, d, a, x[15], 22, md5_T[16])

        -- Round 2
        a = md5_gg(a, b, c, d, x[1], 5, md5_T[17])
        d = md5_gg(d, a, b, c, x[6], 9, md5_T[18])
        c = md5_gg(c, d, a, b, x[11], 14, md5_T[19])
        b = md5_gg(b, c, d, a, x[0], 20, md5_T[20])
        a = md5_gg(a, b, c, d, x[5], 5, md5_T[21])
        d = md5_gg(d, a, b, c, x[10], 9, md5_T[22])
        c = md5_gg(c, d, a, b, x[15], 14, md5_T[23])
        b = md5_gg(b, c, d, a, x[4], 20, md5_T[24])
        a = md5_gg(a, b, c, d, x[9], 5, md5_T[25])
        d = md5_gg(d, a, b, c, x[14], 9, md5_T[26])
        c = md5_gg(c, d, a, b, x[3], 14, md5_T[27])
        b = md5_gg(b, c, d, a, x[8], 20, md5_T[28])
        a = md5_gg(a, b, c, d, x[13], 5, md5_T[29])
        d = md5_gg(d, a, b, c, x[2], 9, md5_T[30])
        c = md5_gg(c, d, a, b, x[7], 14, md5_T[31])
        b = md5_gg(b, c, d, a, x[12], 20, md5_T[32])

        -- Round 3
        a = md5_hh(a, b, c, d, x[5], 4, md5_T[33])
        d = md5_hh(d, a, b, c, x[8], 11, md5_T[34])
        c = md5_hh(c, d, a, b, x[11], 16, md5_T[35])
        b = md5_hh(b, c, d, a, x[14], 23, md5_T[36])
        a = md5_hh(a, b, c, d, x[1], 4, md5_T[37])
        d = md5_hh(d, a, b, c, x[4], 11, md5_T[38])
        c = md5_hh(c, d, a, b, x[7], 16, md5_T[39])
        b = md5_hh(b, c, d, a, x[10], 23, md5_T[40])
        a = md5_hh(a, b, c, d, x[13], 4, md5_T[41])
        d = md5_hh(d, a, b, c, x[0], 11, md5_T[42])
        c = md5_hh(c, d, a, b, x[3], 16, md5_T[43])
        b = md5_hh(b, c, d, a, x[6], 23, md5_T[44])
        a = md5_hh(a, b, c, d, x[9], 4, md5_T[45])
        d = md5_hh(d, a, b, c, x[12], 11, md5_T[46])
        c = md5_hh(c, d, a, b, x[15], 16, md5_T[47])
        b = md5_hh(b, c, d, a, x[2], 23, md5_T[48])

        -- Round 4
        a = md5_ii(a, b, c, d, x[0], 6, md5_T[49])
        d = md5_ii(d, a, b, c, x[7], 10, md5_T[50])
        c = md5_ii(c, d, a, b, x[14], 15, md5_T[51])
        b = md5_ii(b, c, d, a, x[5], 21, md5_T[52])
        a = md5_ii(a, b, c, d, x[12], 6, md5_T[53])
        d = md5_ii(d, a, b, c, x[3], 10, md5_T[54])
        c = md5_ii(c, d, a, b, x[10], 15, md5_T[55])
        b = md5_ii(b, c, d, a, x[1], 21, md5_T[56])
        a = md5_ii(a, b, c, d, x[8], 6, md5_T[57])
        d = md5_ii(d, a, b, c, x[15], 10, md5_T[58])
        c = md5_ii(c, d, a, b, x[6], 15, md5_T[59])
        b = md5_ii(b, c, d, a, x[13], 21, md5_T[60])
        a = md5_ii(a, b, c, d, x[4], 6, md5_T[61])
        d = md5_ii(d, a, b, c, x[11], 10, md5_T[62])
        c = md5_ii(c, d, a, b, x[2], 15, md5_T[63])
        b = md5_ii(b, c, d, a, x[9], 21, md5_T[64])

        a = toUint32(a + aa)
        b = toUint32(b + bb)
        c = toUint32(c + cc)
        d = toUint32(d + dd)
    end

    -- Output as hex (little-endian words)
    return string.format("%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
        band(a, 0xFF), band(rshift(a, 8), 0xFF), band(rshift(a, 16), 0xFF), band(rshift(a, 24), 0xFF),
        band(b, 0xFF), band(rshift(b, 8), 0xFF), band(rshift(b, 16), 0xFF), band(rshift(b, 24), 0xFF),
        band(c, 0xFF), band(rshift(c, 8), 0xFF), band(rshift(c, 16), 0xFF), band(rshift(c, 24), 0xFF),
        band(d, 0xFF), band(rshift(d, 8), 0xFF), band(rshift(d, 16), 0xFF), band(rshift(d, 24), 0xFF))
end

-- ===== PBKDF2-HMAC-SHA-256 =====
function fallback.kdf_derive_sha256(password, salt_b64, iterations)
    local salt = fallback.decode_base64(salt_b64)
    local pw_bytes = { password:byte(1, #password) }
    local dklen = 32
    local hlen = 32 -- SHA-256 output is 32 bytes

    local num_blocks = math.ceil(dklen / hlen)
    local result = {}

    for block = 1, num_blocks do
        -- U1 = HMAC(password, salt || INT(block))
        local int_block = string.char(
            band(rshift(block, 24), 0xFF),
            band(rshift(block, 16), 0xFF),
            band(rshift(block, 8), 0xFF),
            band(block, 0xFF)
        )
        local u = hmac_sha256(pw_bytes, salt .. int_block)
        local u_bytes = {}
        for i = 1, #u, 2 do u_bytes[#u_bytes + 1] = tonumber(u:sub(i, i + 1), 16) end

        local block_result = ""
        for i = 1, hlen do block_result = block_result .. string.char(u_bytes[i] or 0) end

        for iter = 2, iterations do
            -- U_next = HMAC(password, U_prev)
            local u_hex = hmac_sha256(pw_bytes, table.concat(u_bytes))
            u_bytes = {}
            for i = 1, #u_hex, 2 do u_bytes[#u_bytes + 1] = tonumber(u_hex:sub(i, i + 1), 16) end

            -- XOR into block_result
            local xored = {}
            for i = 1, hlen do
                local prev = block_result:byte(i) or 0
                xored[i] = string.char(bxor(prev, u_bytes[i] or 0))
            end
            block_result = table.concat(xored)
        end

        result[#result + 1] = block_result
    end

    return table.concat(result):sub(1, dklen)
end

-- ===== Random bytes (using Love2D's random, not crypto-secure — fine for nonces) =====
function fallback.random_bytes(n)
    local bytes = {}
    for i = 1, n do
        bytes[i] = string.char(love.math.random(0, 255))
    end
    return table.concat(bytes)
end

return fallback
