local airtable = require("utils/airtable")

local auth = {}

function auth.checkKey(apikey)
    if type(apikey) ~= "string" or apikey == "" then
        return false
    end

    local quotedKey = '"' .. apikey .. '"'
    local formula = "{key} = " .. quotedKey

    local ok, result = pcall(airtable.list_records, "API Keys", "Grid view", {filterByFormula = formula})
    if not ok or type(result) ~= "table" then
        return false
    end

    if not result.records or type(result.records) ~= "table" or #result.records == 0 then
        return false
    end

    local first = result.records[1]
    if not first or type(first) ~= "table" or type(first.fields) ~= "table" then
        return false
    end

    local fields = first.fields
    if fields.key == apikey then
        return fields.perms or false
    end

    return false
end

function auth.getKeyName(apikey)
    if type(apikey) ~= "string" or apikey == "" then
        return "None"
    end

    local quotedKey = '"' .. apikey .. '"'
    local formula = "{key} = " .. quotedKey

    local ok, result = pcall(airtable.list_records, "API Keys", "Grid view", {filterByFormula = formula})
    if not ok or type(result) ~= "table" then
        return "None"
    end

    if not result.records or type(result.records) ~= "table" or #result.records == 0 then
        return "None"
    end

    local first = result.records[1]
    if not first or type(first) ~= "table" or type(first.fields) ~= "table" then
        return "None"
    end

    local fields = first.fields
    if fields.key == apikey then
        return fields.name or "None"
    end

    return "None"
end

function auth.checkRead(apikey)
    local perms = auth.checkKey(apikey)
    if type(perms) ~= "string" then
        return false
    end

    if perms == "admin" or perms == "read" or perms == "write" then
        return true
    end

    return false
end

function auth.checkWrite(apikey)
    local perms = auth.checkKey(apikey)
    if type(perms) ~= "string" then
        return false
    end

    if perms == "admin" or perms == "write" then
        return true
    end

    return false
end

function auth.checkAdmin(apikey)
    local perms = auth.checkKey(apikey)
    if type(perms) ~= "string" then
        return false
    end

    return perms == "admin"
end

return auth
