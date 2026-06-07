local misc = {}

function misc.tableToString(tbl, indent)
    if type(tbl) ~= "table" then return tostring(tbl) end
    indent = indent or 0
    local prefix = string.rep("  ", indent)
    local parts = { "{" }
    for k, v in pairs(tbl) do
        local keyStr = tostring(k)
        local valStr = type(v) == "table" and tableToString(v, indent + 1) or tostring(v)
        table.insert(parts, prefix .. "  " .. keyStr .. " = " .. valStr)
    end
    table.insert(parts, prefix .. "}")
    if #parts == 2 then return "{}" end
    return table.concat(parts, "\n")
end

return misc
