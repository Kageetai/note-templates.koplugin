-- Optional source-contract test: pass readerbookmark.lua from a tagged release.
-- This executes native callbacks with stub widgets; it is not an emulator test.
assert(arg[1], "Usage: luajit tests/upstream_test.lua /path/to/readerbookmark.lua")
local stubs = dofile("tests/stubs.lua")
local UIManager, InputDialog = stubs.UIManager, stubs.InputDialog
local Plugin = dofile("main.lua")
local file = assert(io.open(arg[1], "r"))
local source = file:read("*a")
file:close()
local first = assert(source:find("function ReaderBookmark:setBookmarkNote(", 1, true))
local last = assert(source:find("\nfunction ReaderBookmark:", first + 1, true))
local ReaderBookmark = {}
local chunk = assert(loadstring(source:sub(first, last - 1)))
setfenv(chunk, setmetatable({
    ReaderBookmark = ReaderBookmark, InputDialog = InputDialog, UIManager = UIManager,
    Event = { new = function(_, ...) return { ... } end },
    _ = function(text) return text end,
}, { __index = _G }))
chunk()
G_reader_settings = stubs.settings({ { text = "日本語", suffix = "blank_line" } })

for _, from_list in ipairs({ false, true }) do
    for _, is_new in ipairs({ false, true }) do
        local annotation = { note = not is_new and "existing" or nil, text = "highlight" }
        local item = { note = annotation.note, type = "bookmark", idx = 1 }
        local notifications, pdf_writes, callbacks, removals = 0, 0, 0, 0
        local bookmark = {
            setBookmarkNote = ReaderBookmark.setBookmarkNote,
            bookmark_menu = from_list and {} or nil,
            getBookmarkItemIndex = function(_, received) assert(received == item); return 1 end,
            getBookmarkType = function(a) return a.note and "note" or "highlight" end,
            getBookmarkItemText = function() return "updated" end,
            _getDialogHeader = function() return "Page 1" end,
            removeItemByIndex = function(_, index) assert(index == 1); removals = removals + 1 end,
            ui = {
                annotation = { annotations = { annotation } },
                highlight = { writePdfAnnotation = function(_, kind, a, value)
                    assert(kind == "content" and a == annotation and value == "日本語\n\n")
                    pdf_writes = pdf_writes + 1
                end },
                handleEvent = function() notifications = notifications + 1 end,
            },
        }
        local p = Plugin:extend{ ui = { bookmark = bookmark } }
        p:installNoteHook()
        local new_raw = rawget(InputDialog, "new")
        bookmark:setBookmarkNote(from_list and item or 1, is_new, nil, function() callbacks = callbacks + 1 end)
        local editor = UIManager:last()
        assert(#editor.buttons == 2 and editor.keyboard_shown)
        assert(rawget(InputDialog, "new") == new_raw)
        editor.buttons[2][1].callback()
        local picker = UIManager:last()
        picker:onMenuSelect(picker.item_table[1])
        assert(editor.inserted == "日本語\n\n")
        assert(callbacks == 0 and pdf_writes == 0 and removals == 0)
        -- Let the native Save callback read the value produced by its public input API.
        editor.input = editor.inserted
        editor.buttons[1][3].callback()
        assert(annotation.note == "日本語\n\n" and callbacks == 1)
        if source:find('writePdfAnnotation("content"', first, true) then assert(pdf_writes == 1) end
        if from_list then assert(item.note == "日本語\n\n" and item.text == "updated") end
        local saved = annotation.note
        bookmark:setBookmarkNote(from_list and item or 1, is_new, nil, function() callbacks = callbacks + 1 end)
        editor = UIManager:last()
        editor.buttons[1][1].callback()
        assert(annotation.note == saved and callbacks == 1)
        assert(removals == (is_new and 1 or 0))
        assert(#InputDialog:new{ buttons = {{}} }.buttons == 1)
    end
end
print("upstream_test: passed (stubbed UI): " .. arg[1])
