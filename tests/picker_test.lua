local stubs = dofile("tests/stubs.lua")
local UIManager = stubs.UIManager
local Plugin = dofile("main.lua")
local p = Plugin:extend{ ui = {} }

local entries = {
    { text = ".c1", suffix = "space" },
    { text = "日本語\nnext line", suffix = "blank_line" },
    { text = ".c2", suffix = "newline" },
    { text = "  literal  ", suffix = "none" },
}
G_reader_settings = stubs.settings(entries)
local note = stubs.InputDialog:new{ input = "existing note", cursor = 4 }
note:onShowKeyboard()
UIManager:show(note)
for i, expected in ipairs({ ".c1 ", "日本語\nnext line\n\n", ".c2\n", "  literal  " }) do
    p:showPicker(note)
    local picker = UIManager:last()
    assert(note:isKeyboardVisible() == false, "Hide the keyboard before showing the picker")
    assert(#picker.item_table == 4)
    assert(picker.item_table[1].text == ".c1")
    assert(not picker.item_table[2].text:find("[\r\n]"))
    note.inserted = nil
    picker:onMenuSelect(picker.item_table[i])
    assert(note.inserted == expected)
    assert(UIManager.closed[#UIManager.closed] == picker)
    assert(note.input == "existing note" and G_reader_settings.writes == 0)
    assert(note:isKeyboardVisible() == true, "Restore the keyboard after selection")
end

-- Dismissing selection changes no editor state, and repeated insertion is literal.
p:showPicker(note)
local picker = UIManager:last()
note.inserted = nil
picker.close_callback()
assert(note.inserted == nil and note:isKeyboardVisible() == true and note.input == "existing note" and note.cursor == 4)
p:showPicker(note)
picker = UIManager:last()
picker:onMenuSelect(picker.item_table[1])
p:showPicker(note)
picker = UIManager:last()
picker:onMenuSelect(picker.item_table[1])
assert(note.inserted == ".c1 .c1 ")

-- A keyboard that was hidden stays hidden after selection and dismissal.
note:onCloseKeyboard()
local shows = note.keyboard_shows
p:showPicker(note)
picker = UIManager:last()
picker:onMenuSelect(picker.item_table[1])
assert(note:isKeyboardVisible() == false and note.keyboard_shows == shows)
p:showPicker(note)
UIManager:last().close_callback()
assert(note:isKeyboardVisible() == false and note.keyboard_shows == shows)

for _, value in ipairs({ {}, false, { { text = "keep", suffix = "broken" } } }) do
    G_reader_settings = stubs.settings(value)
    local previous = note.inserted
    p:showPicker(note)
    assert(UIManager:last().text)
    assert(note.inserted == previous and G_reader_settings.value == value and G_reader_settings.writes == 0)
end
for _, closed in ipairs(UIManager.closed) do assert(closed ~= note) end
print("picker_test: passed")
