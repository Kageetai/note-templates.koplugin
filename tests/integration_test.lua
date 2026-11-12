local stubs = dofile("tests/stubs.lua")
local InputDialog, UIManager = stubs.InputDialog, stubs.UIManager
local Plugin = dofile("main.lua")
local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
local function options()
    return {
        input = "before", allow_newline = true, add_scroll_buttons = true,
        use_available_height = true,
        buttons = {{
            { id = "close", callback = function() return "cancel" end },
            { callback = function() return "paste" end },
            { is_enter_default = true, callback = function() return "save" end },
        }},
    }
end
local function pluginFor(bookmark)
    return Plugin:extend{ ui = { bookmark = bookmark } }
end

-- Removing restoration, forwarding, or the per-reader guard must fail here.
local inherited_new = InputDialog.new
assert(rawget(InputDialog, "new") == nil)
local first, second, callback_row, dialog_options
local args = pack("annotation", nil, "追加", function() end, nil)
local bookmark = {}
local original = function(self, ...)
    assert(self == bookmark)
    local received = pack(...)
    assert(received.n == args.n)
    for i = 1, args.n do assert(received[i] == args[i]) end
    dialog_options = options()
    callback_row = dialog_options.buttons[1]
    first = InputDialog:new(dialog_options)
    assert(InputDialog.new == inherited_new)
    second = InputDialog:new(options())
    return "result", nil, 42, nil
end
bookmark.setBookmarkNote = original
local plugin = pluginFor(bookmark)
local picked
plugin.showPicker = function(self, dialog) assert(self == plugin); picked = dialog end
plugin:installNoteHook()
local wrapped = bookmark.setBookmarkNote
plugin:installNoteHook()
assert(bookmark.setBookmarkNote == wrapped)
for _ = 1, 2 do
    local result = pack(bookmark:setBookmarkNote(unpack(args, 1, args.n)))
    assert(result.n == 4 and result[1] == "result" and result[3] == 42)
    assert(rawget(InputDialog, "new") == nil and InputDialog.new == inherited_new)
    assert(#first.buttons == 2 and #second.buttons == 1)
    assert(first.buttons[1] == callback_row)
    assert(callback_row[1].callback() == "cancel")
    assert(callback_row[2].callback() == "paste")
    assert(callback_row[3].callback() == "save")
    first.buttons[2][1].callback()
    assert(picked == first)
end
assert(#InputDialog:new(options()).buttons == 1) -- unrelated input

-- Errors before, inside, and after construction preserve the exact error value.
local sentinel = {}
for _, phase in ipairs({ "before", "constructor", "after" }) do
    InputDialog.new = phase == "constructor" and function() error(sentinel) end or nil
    local previous_raw, previous = rawget(InputDialog, "new"), InputDialog.new
    local failing = { setBookmarkNote = function()
        if phase == "before" then error(sentinel) end
        InputDialog:new(options())
        error(sentinel)
    end }
    pluginFor(failing):installNoteHook()
    local ok, err = pcall(failing.setBookmarkNote, failing)
    assert(not ok and err == sentinel)
    assert(rawget(InputDialog, "new") == previous_raw and InputDialog.new == previous)
end
InputDialog.new = nil

-- A pre-existing constructor wrapper receives the same arguments and survives.
local calls = 0
local previous_wrapper
previous_wrapper = function(class, opts, extra)
    assert(class == InputDialog and extra == "extra")
    calls = calls + 1
    assert(InputDialog.new == previous_wrapper)
    return inherited_new(class, opts), "constructor-result"
end
InputDialog.new = previous_wrapper
local constructor_bookmark = { setBookmarkNote = function()
    return InputDialog:new(options(), "extra")
end }
pluginFor(constructor_bookmark):installNoteHook()
local constructed, extra = constructor_bookmark:setBookmarkNote()
assert(#constructed.buttons == 2 and extra == "constructor-result" and calls == 1)
assert(InputDialog.new == previous_wrapper)
InputDialog.new = nil

-- Unexpected shapes are consumed once and delegated without decoration.
local malformed = { false, {}, { buttons = {} }, { buttons = {{ { callback = function() end } }} } }
for _, opts in ipairs(malformed) do
    local seen
    InputDialog.new = function(_, value) seen = value; return value end
    local delegate = InputDialog.new
    local native_second
    local odd = { setBookmarkNote = function()
        InputDialog:new(opts)
        native_second = InputDialog:new(options())
        return "native"
    end }
    local p = pluginFor(odd)
    p:installNoteHook()
    assert(odd:setBookmarkNote() == "native")
    assert(#native_second.buttons == 1 and InputDialog.new == delegate)
    assert(seen == native_second)
end
InputDialog.new = nil

-- Unsupported APIs leave native editing usable and warn once per session.
UIManager:reset()
local UnsupportedPlugin = dofile("main.lua")
UnsupportedPlugin:extend{ ui = { bookmark = {} } }:installNoteHook()
UnsupportedPlugin:extend{ ui = { bookmark = {} } }:installNoteHook()
assert(#UIManager.shown == 1 and UIManager:last().text:find("2024.07", 1, true))
local missing_insertion = InputDialog.addTextToInput
InputDialog.addTextToInput = nil
local no_insertion = { setBookmarkNote = function() return "native" end }
local native = no_insertion.setBookmarkNote
pluginFor(no_insertion):installNoteHook()
assert(no_insertion.setBookmarkNote == native and no_insertion:setBookmarkNote() == "native")
InputDialog.addTextToInput = missing_insertion
print("integration_test: passed")
