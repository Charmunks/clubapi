
local url = {}

function url.parse_query(uri)
    -- extract the part after "?"
    local query = uri:match("%?(.*)")
    if not query then
        return {} -- no params
    end

    local params = {}

    for key, value in query:gmatch("([^&=?]+)=([^&=?]+)") do
        -- decode percent encoding if needed
        key = key:gsub("%+", " ")
        key = key:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
        value = value:gsub("%+", " ")
        value = value:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)

        -- Treat '+' as a space after decoding, except for fields where a literal '+' is expected (e.g. emails or announcement messages)
        if key ~= "email" and key ~= "new_email" and key ~= "old_email" and key ~= "message" then
            value = value:gsub("%+", " ")
        end

        if not (value:sub(1, 1) == '"' and value:sub(-1) == '"') then
            value = '"' .. value .. '"'
        end

        params[key] = value
    end

    return params
end

function url.strip_quotes(str)
    if type(str) ~= "string" then return str end
    local first = str:sub(1, 1)
    local last = str:sub(-1)
    if (first == '"' and last == '"') or (first == "'" and last == "'") then
        return str:sub(2, -2)
    end
    return str
end




return url
