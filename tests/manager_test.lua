local stubs = dofile("tests/stubs.lua")
local UIManager = stubs.UIManager
local Plugin = dofile("main.lua")
local function instance(value)
    G_reader_settings = stubs.settings(value)
    UIManager:reset()
    local p = Plugin:extend{ ui = { menu = {
        registerToMainMenu = function(_, registered) assert(registered.name == "note_templates") end,
    } } }
    p:init()
    return p, G_reader_settings
end
local function button(widget, text)
    for _, row in ipairs(widget.buttons) do
        for _, item in ipairs(row) do
            if item.text == text then return item end
        end
    end
    error("Missing button: " .. text)
end

-- Only an absent setting seeds examples; neither empty nor malformed data is replaced.
local p, settings = instance(nil)
assert(settings.writes == 1 and #settings.value == 3)
assert(settings.value[1].text == ".words" and settings.value[1].suffix == "space")
assert(settings.value[2].text == ".c1" and settings.value[3].text == ".c2")
local _, empty = instance({})
assert(#empty.value == 0 and empty.writes == 0)
local malformed = { { text = "keep", suffix = "invalid" } }
local invalid, persisted = instance(malformed)
invalid:showManager()
assert(persisted.value == malformed and persisted.writes == 0)
assert(UIManager:last().text:find("note_templates", 1, true))

-- Editing is staged until Save, suffix selection included; editing preserves position.
p, settings = instance({ { text = "first", suffix = "none" }, { text = "second", suffix = "newline" } })
p:editTemplate(1)
local editor = UIManager:last()
assert(editor.allow_newline == true and editor.input == "first")
editor.input = "cancelled"
button(editor, "Trailing text: Nothing").callback()
button(UIManager:last(), "Newline").callback()
button(editor, "Cancel").callback()
assert(settings.value[1].text == "first" and settings.value[1].suffix == "none" and settings.writes == 0)
p:editTemplate(1)
editor = UIManager:last()
editor.input = "  日本語\nnext line  "
button(editor, "Trailing text: Nothing").callback()
local chooser = UIManager:last()
local suffix_button = editor.button_table:getButtonById("suffix")
local width = suffix_button.width
button(chooser, "Blank line").callback()
assert(settings.writes == 0)
assert(suffix_button.text == "Trailing text: Blank line")
assert(suffix_button.width == width, "Suffix updates must preserve the button's assigned width")
editor:reinit()
assert(editor.button_table:getButtonById("suffix").text == "Trailing text: Blank line",
    "Dialog recreation must display the staged suffix")
button(editor, "Save").callback()
assert(settings.value[1].text == "  日本語\nnext line  ")
assert(settings.value[1].suffix == "blank_line" and settings.value[2].text == "second")
assert(settings.writes == 1)

-- Adding appends and defaults to Space; an empty save keeps the editor available.
p:editTemplate()
editor = UIManager:last()
assert(#editor.buttons[2] == 2, "New templates have no Delete action")
editor.input = ""
button(editor, "Save").callback()
assert(#settings.value == 2 and settings.writes == 1)
assert(UIManager:last().text:find("empty"))
editor.input = "last"
button(editor, "Save").callback()
assert(#settings.value == 3 and settings.value[3].text == "last" and settings.value[3].suffix == "space")

-- Confirmed deletion persists, while dismissing confirmation leaves the data intact.
p:deleteTemplate(2)
assert(#settings.value == 3 and UIManager:last().ok_callback)
p:deleteTemplate(2)
UIManager:last().ok_callback()
assert(#settings.value == 2 and settings.value[1].text == "  日本語\nnext line  " and settings.value[2].text == "last")
p:deleteTemplate(2)
UIManager:last().ok_callback()
p:deleteTemplate(1)
UIManager:last().ok_callback()
assert(#settings.value == 0)
local _, restarted = instance(settings.value)
assert(#restarted.value == 0 and restarted.writes == 0)

-- The manager exposes Add and previews in stored order without changing literal text.
p = instance({ { text = "one\ntwo\r\nthree", suffix = "none" }, { text = ".c1", suffix = "space" } })
local menu_items = {}
p:addToMainMenu(menu_items)
assert(menu_items.note_templates.sorting_hint == "tools")
menu_items.note_templates.callback()
local manager = UIManager:last()
assert(#manager.item_table == 3 and manager.item_table[1].text == "Add template")
assert(not manager.item_table[2].text:find("[\r\n]"))
assert(manager.item_table[3].text == ".c1")
manager:onMenuSelect(manager.item_table[3])
editor = UIManager:last()
assert(editor.input == ".c1", "Selecting a template must open its editor directly")
editor.input = "unsaved edit"
button(editor, "Delete").callback()
local confirmation = UIManager:last()
assert(confirmation.ok_callback and G_reader_settings.writes == 0)
assert(not editor:isKeyboardVisible())
confirmation.cancel_callback()
assert(editor.input == "unsaved edit" and editor:isKeyboardVisible())
button(editor, "Delete").callback()
UIManager:last().ok_callback()
assert(#G_reader_settings.value == 1 and G_reader_settings.value[1].text == "one\ntwo\r\nthree")
local editor_closed = false
for _, closed in ipairs(UIManager.closed) do
    if closed == editor then editor_closed = true end
end
assert(editor_closed, "Confirmed deletion must close the editor")

print("manager_test: passed")
