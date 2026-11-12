local ButtonDialog = require("ui/widget/buttondialog")
local ConfirmBox = require("ui/widget/confirmbox")
local InfoMessage = require("ui/widget/infomessage")
local InputDialog = require("ui/widget/inputdialog")
local Menu = require("ui/widget/menu")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local templates = require("templates")
local _ = require("gettext")

local NoteTemplates = WidgetContainer:extend{
    name = "note_templates",
    is_doc_only = false,
}

local unpack = unpack or table.unpack
local function pack(...)
    return { n = select("#", ...), ... }
end

local suffix_choices = {
    { value = "none", text = _("Nothing") },
    { value = "space", text = _("Space") },
    { value = "newline", text = _("Newline") },
    { value = "blank_line", text = _("Blank line") },
}

local function preview(text)
    return (text:gsub("\r\n", " ↵ "):gsub("[\r\n]", " ↵ "))
end

function NoteTemplates:init()
    if G_reader_settings:readSetting("note_templates") == nil then
        G_reader_settings:saveSetting("note_templates", {
            { text = ".words", suffix = "space" },
            { text = ".c1", suffix = "space" },
            { text = ".c2", suffix = "space" },
        })
    end
    self.ui.menu:registerToMainMenu(self)
    if self.ui.document then self:installNoteHook() end
end

function NoteTemplates:readEntries()
    local entries = G_reader_settings:readSetting("note_templates")
    local valid, err = templates.validate(entries)
    if not valid then
        UIManager:show(InfoMessage:new{
            text = _("Note templates settings are invalid. The stored note_templates value was preserved. Back up and repair this setting in KOReader's settings.reader.lua, then restart KOReader.") .. "\n\n" .. err,
        })
        return
    end
    return entries
end

function NoteTemplates:addToMainMenu(menu_items)
    menu_items.note_templates = {
        text = _("Note templates"),
        sorting_hint = "tools",
        callback = function() self:showManager() end,
    }
end

local function showMenu(title, items, on_close)
    local menu
    menu = Menu:new{
        title = title,
        item_table = items,
        close_callback = function()
            UIManager:close(menu)
            if on_close then on_close() end
        end,
    }
    UIManager:show(menu)
end

function NoteTemplates:showPicker(input_dialog)
    local entries = self:readEntries()
    if not entries then return end
    if #entries == 0 then
        UIManager:show(InfoMessage:new{
            text = _("No note templates. Add one in the main menu under Tools → Note templates."),
        })
        return
    end
    local items = {}
    for _, entry in ipairs(entries) do
        local template = entry
        items[#items + 1] = {
            text = preview(template.text),
            callback = function()
                local text, err = templates.insertionText(template)
                if not text then
                    UIManager:show(InfoMessage:new{ text = err })
                    return
                end
                input_dialog:addTextToInput(text)
            end,
        }
    end
    local keyboard_was_visible = input_dialog:isKeyboardVisible()
    input_dialog:onCloseKeyboard()
    showMenu(_("Note templates"), items, function()
        if keyboard_was_visible then input_dialog:onShowKeyboard() end
    end)
end

function NoteTemplates:showManager()
    local entries = self:readEntries()
    if not entries then return end
    local items = {{ text = _("Add template"), callback = function() self:editTemplate() end }}
    for i, entry in ipairs(entries) do
        local index = i
        items[#items + 1] = {
            text = preview(entry.text),
            callback = function() self:editTemplate(index) end,
        }
    end
    showMenu(_("Note templates"), items)
end

function NoteTemplates:editTemplate(index)
    local entries = self:readEntries()
    if not entries or (index and not entries[index]) then return end
    local entry = index and entries[index]
    local suffix = entry and entry.suffix or "space"
    local function suffixLabel()
        for i, choice in ipairs(suffix_choices) do
            if choice.value == suffix then return _("Trailing text:") .. " " .. choice.text end
        end
    end
    local editor
    local options = {
        title = index and _("Edit template") or _("Add template"),
        input = entry and entry.text or "",
        allow_newline = true,
        add_scroll_buttons = true,
        buttons = {
            {{ id = "suffix", text = suffixLabel(), text_func = suffixLabel, callback = function()
                local chooser, rows
                rows = {}
                for _, choice in ipairs(suffix_choices) do
                    local value = choice.value
                    rows[#rows + 1] = {{ text = choice.text, callback = function()
                        suffix = value
                        local button = editor.button_table:getButtonById("suffix")
                        button:setText(suffixLabel(), button.width)
                        UIManager:close(chooser)
                    end }}
                end
                chooser = ButtonDialog:new{ title = _("Trailing text"), buttons = rows }
                UIManager:show(chooser)
            end }},
            {
                { text = _("Cancel"), id = "close", callback = function() UIManager:close(editor) end },
                { text = _("Save"), is_enter_default = true, callback = function()
                    local updated = { text = editor:getInputText(), suffix = suffix }
                    local valid, err = templates.validate({ updated })
                    if not valid then
                        UIManager:show(InfoMessage:new{ text = err })
                        return
                    end
                    local current = self:readEntries()
                    if not current then return end
                    current[index or (#current + 1)] = updated
                    G_reader_settings:saveSetting("note_templates", current)
                    UIManager:close(editor)
                    self:showManager()
                end },
            },
        },
    }
    if index then
        table.insert(options.buttons[2], 2, {
            text = _("Delete"),
            callback = function() self:deleteTemplate(index, editor) end,
        })
    end
    editor = InputDialog:new(options)
    UIManager:show(editor)
    editor:onShowKeyboard()
end

function NoteTemplates:deleteTemplate(index, editor)
    local entries = self:readEntries()
    if not entries or not entries[index] then return end
    local keyboard_was_visible = editor and editor:isKeyboardVisible()
    if editor then editor:onCloseKeyboard() end
    UIManager:show(ConfirmBox:new{
        text = _("Delete this template?") .. "\n\n" .. preview(entries[index].text),
        ok_text = _("Delete"),
        cancel_callback = function()
            if keyboard_was_visible then editor:onShowKeyboard() end
        end,
        ok_callback = function()
            local current = self:readEntries()
            if not current or not current[index] then return end
            table.remove(current, index)
            G_reader_settings:saveSetting("note_templates", current)
            if editor then UIManager:close(editor) end
            self:showManager()
        end,
    })
end

local compatibility_reported = false
function NoteTemplates:reportCompatibility()
    if compatibility_reported then return end
    compatibility_reported = true
    UIManager:show(InfoMessage:new{
        text = _("Note templates could not attach to this note editor. Use KOReader 2024.07 or later and check for conflicting note-editor plugins. Normal note editing is still available."),
    })
end

local function isNoteOptions(options)
    if type(options) ~= "table" or options.allow_newline ~= true
            or options.add_scroll_buttons ~= true or options.use_available_height ~= true
            or type(options.buttons) ~= "table" or #options.buttons ~= 1 then
        return false
    end
    local row = options.buttons[1]
    if type(row) ~= "table" or #row ~= 3 then return false end
    for i = 1, 3 do
        if type(row[i]) ~= "table" or type(row[i].callback) ~= "function" then
            return false
        end
    end
    return row[1].id == "close" and row[3].is_enter_default == true
end

function NoteTemplates:installNoteHook()
    local bookmark = self.ui.bookmark
    if not bookmark or type(bookmark.setBookmarkNote) ~= "function"
            or type(InputDialog.addTextToInput) ~= "function" then
        self:reportCompatibility()
        return
    end
    if bookmark._note_templates_hook then return end
    local original = bookmark.setBookmarkNote
    bookmark._note_templates_hook = true
    bookmark.setBookmarkNote = function(bookmark_self, ...)
        local previous_raw, previous = rawget(InputDialog, "new"), InputDialog.new
        local decorated = false
        -- KOReader exposes no note-editor hook; intercept only its synchronous first constructor.
        InputDialog.new = function(class, options, ...)
            rawset(InputDialog, "new", previous_raw)
            local dialog
            if class == InputDialog and isNoteOptions(options) then
                decorated = true
                table.insert(options.buttons, {{
                    text = _("Templates"),
                    callback = function() self:showPicker(dialog) end,
                }})
            end
            local result = pack(previous(class, options, ...))
            dialog = result[1]
            return unpack(result, 1, result.n)
        end
        local result = pack(pcall(original, bookmark_self, ...))
        rawset(InputDialog, "new", previous_raw)
        if not result[1] then error(result[2], 0) end
        if not decorated then self:reportCompatibility() end
        return unpack(result, 2, result.n)
    end
end

return NoteTemplates
