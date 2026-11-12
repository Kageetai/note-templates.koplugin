-- Native widgets are unavailable outside KOReader; keep the plugin's logic real.
local Widget = {}
function Widget:extend(o)
    self.__index = self
    return setmetatable(o or {}, self)
end
function Widget:new(o)
    return self:extend(o)
end

local UIManager = { shown = {}, closed = {} }
function UIManager:show(widget)
    self.shown[#self.shown + 1] = widget
end
function UIManager:close(widget)
    self.closed[#self.closed + 1] = widget
end
function UIManager:reset()
    self.shown, self.closed = {}, {}
end
function UIManager:last()
    return self.shown[#self.shown]
end

local InputBase = Widget:extend{}
function InputBase:reinit()
    local rendered = {}
    for _, row in ipairs(self.buttons or {}) do
        for _, entry in ipairs(row) do
            if entry.id then
                local button = {}
                for key, value in pairs(entry) do button[key] = value end
                button.width = 120
                button.text = button.text_func and button.text_func() or button.text
                button.setText = function(b, text, width)
                    b.text, b.width = text, width or #text * 8
                end
                rendered[entry.id] = button
            end
        end
    end
    self.button_table = { getButtonById = function(_, id) return rendered[id] end }
end
function InputBase:new(o)
    o = self:extend(o)
    o:reinit()
    return o
end
local InputDialog = InputBase:extend{}
function InputDialog:addTextToInput(text)
    self.inserted = (self.inserted or "") .. text
end
function InputDialog:getInputText()
    return self.input or ""
end
function InputDialog:onShowKeyboard()
    self.keyboard_shown = true
    self.keyboard_visible = true
    self.keyboard_shows = (self.keyboard_shows or 0) + 1
end
function InputDialog:onCloseKeyboard()
    self.keyboard_visible = false
end
function InputDialog:isKeyboardVisible()
    return self.keyboard_visible
end

package.loaded["ui/widget/container/widgetcontainer"] = Widget
package.loaded["ui/widget/inputdialog"] = InputDialog
for _, name in ipairs({ "menu", "buttondialog", "confirmbox", "infomessage" }) do
    package.loaded["ui/widget/" .. name] = Widget:extend{}
end
-- Native Menu invokes the item action before its close callback.
local Menu = package.loaded["ui/widget/menu"]
function Menu:onMenuSelect(item)
    item.callback()
    self.close_callback()
end
package.loaded["ui/uimanager"] = UIManager
package.loaded["gettext"] = function(text) return text end

local function settings(value)
    return {
        value = value,
        writes = 0,
        readSetting = function(self, key)
            assert(key == "note_templates")
            return self.value
        end,
        saveSetting = function(self, key, entries)
            assert(key == "note_templates")
            self.value = entries
            self.writes = self.writes + 1
        end,
    }
end

return { Widget = Widget, InputDialog = InputDialog, UIManager = UIManager, settings = settings }
