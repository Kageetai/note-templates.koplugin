local suffixes = { none = "", space = " ", newline = "\n", blank_line = "\n\n" }
local templates = {}

function templates.validate(entries)
    if type(entries) ~= "table" then
        return nil, "Expected an ordered list of templates."
    end
    local count = 0
    for key in pairs(entries) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
            return nil, "Templates must use consecutive numeric positions."
        end
        count = count + 1
    end
    for i = 1, count do
        local entry = entries[i]
        if type(entry) ~= "table" or type(entry.text) ~= "string" or entry.text == "" then
            return nil, "Template " .. i .. " must contain nonempty text."
        end
        if type(entry.suffix) ~= "string" or suffixes[entry.suffix] == nil then
            return nil, "Template " .. i .. " has an invalid trailing-text choice."
        end
    end
    return true
end

function templates.insertionText(entry)
    local valid, err = templates.validate({ entry })
    if entry == nil then return nil, "Missing template." end
    if not valid then return nil, err end
    return entry.text .. suffixes[entry.suffix]
end

return templates
