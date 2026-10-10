--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Menu for mpvacious
]]

local mp = require('mp')
local msg = require('mp.msg')
local h = require('helpers')

local Menu = {
    active = false,
    keybindings = {},
    overlay = mp.create_osd_overlay and mp.create_osd_overlay('ass-events'),
}

function Menu:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Menu:with_update(params)
    return function(...)
        local to_call = h.combine_lists(params, { ... })
        local status, error = pcall(h.unpack(to_call))
        if not status then
            msg['error'](error)
        end
        self:update()
    end
end

function Menu:make_osd()
    return nil
end

function Menu:update()
    if self.active == false then
        return
    end
    self.overlay.data = self:make_osd():get_text()
    self.overlay:update()
end

function Menu:open()
    if self.overlay == nil then
        h.notify("OSD overlay is not supported in " .. mp.get_property("mpv-version"), "error", 5)
        return
    end

    if self.active == true then
        self:close()
        return
    end

    for _, val in pairs(self.keybindings) do
        -- complex + forced: 与 fastforward.lua 同款，确保压过 input.conf 的同名绑定。
        -- complex 绑定会在 down/up 各触发一次，这里只认 down 事件，避免动作被执行两遍。
        local fn = val.fn
        local function on_down(info)
            if type(info) == "table" and info.event ~= nil and info.event ~= "down" then
                return
            end
            return fn(info)
        end
        mp.add_forced_key_binding(val.key, val.key, on_down, { complex = true })
    end

    -- 每次"从关闭→打开"都回到 basic 视图。
    -- 否则若上次在面板里按 i 切到 'hidden'(隐藏整个菜单体),
    -- 重新按 a 打开时渲染出来仍是空的,表现为"按 a 完全不起效果"。
    if self.hints_state then
        self.hints_state.set('basic')
    end
    self.active = true
    self:update()
end

function Menu:close()
    if self.active == false then
        return
    end

    for _, val in pairs(self.keybindings) do
        mp.remove_key_binding(val.key)
    end

    self.overlay:remove()
    self.active = false
end

return Menu
