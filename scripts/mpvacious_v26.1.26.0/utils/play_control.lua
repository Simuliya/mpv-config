--[[
Copyright: Ajatt-Tools and contributors; https://github.com/Ajatt-Tools
License: GNU GPL, version 3 or later; http://www.gnu.org/licenses/gpl.html

Provides additional methods for controlling playback.

本地修改（仅两处）：
  1. sub_rewind() 增加 nil 保护：光标停在无字幕处时不再抛错。
  2. 新增 toggle_sub_loop()：用 ab-loop 循环当前句字幕。
     pause 命令在 SVP 补帧下约有 0.3 秒延迟，而 ab-loop 的边界由 mpv
     内核直接控制，不受该延迟影响，因此循环比"播完暂停"更准。
]]

local mp = require('mp')
local h = require('helpers')
local pause_timer = require('utils.pause_timer')
local Subtitle = require('subtitles.subtitle')

-- 循环段结尾相对字幕终点留出的余量（秒）
local LOOP_END_MARGIN = 0.050

local current_sub
local looping = false

local function stop_at_the_end(sub)
    pause_timer.set_stop_time(sub['end'] - 0.050)
    h.notify("Playing till the end of the sub...", "info", 3)
end

local function play_till_sub_end()
    local sub = Subtitle:now()
    if not sub then
        h.notify("There's no subtitle to replay.", "info", 2)
        return
    end
    mp.commandv('seek', sub['start'], 'absolute')
    mp.set_property("pause", "no")
    stop_at_the_end(sub)
end

local function sub_seek(direction, pause)
    mp.commandv("sub_seek", direction == 'backward' and '-1' or '1')
    mp.commandv("seek", "0.015", "relative+exact")
    if pause then
        mp.set_property("pause", "yes")
    end
    pause_timer.stop()
end

local function sub_rewind()
    -- 光标停在无字幕处时 Subtitle:now() 返回 nil，
    -- 原版直接取 ['start'] 会抛错，这里给出提示代替。
    local sub = Subtitle:now()
    if not sub then
        h.notify("There's no subtitle to rewind to.", "info", 2)
        return
    end
    mp.commandv('seek', sub['start'] + 0.015, 'absolute')
    pause_timer.stop()
end

local function check_sub()
    local sub = Subtitle:now()
    if sub and sub ~= current_sub then
        mp.unobserve_property(check_sub)
        stop_at_the_end(sub)
    end
end

local function play_till_next_sub_end()
    current_sub = Subtitle:now()
    mp.observe_property("sub-text", "string", check_sub)
    mp.set_property("pause", "no")
    h.notify("Waiting till next sub...", "info", 10)
end

--- 切换当前句的循环播放。
--- 第一次按下：把当前句设为 ab-loop 区间并从头播放。
--- 再按一次：取消循环，继续正常播放。
local function toggle_sub_loop()
    pause_timer.stop()

    if looping then
        looping = false
        mp.set_property('ab-loop-a', 'no')
        mp.set_property('ab-loop-b', 'no')
        -- 取消循环后继续正常播放（不暂停）
        mp.set_property('pause', 'no')
        return
    end

    local sub = Subtitle:now()
    if not sub then
        h.notify("There's no subtitle to loop.", 'info', 2)
        return
    end

    local from = sub['start']
    local to = sub['end'] - LOOP_END_MARGIN
    if to <= from then
        to = sub['end']
    end

    mp.set_property('ab-loop-a', from)
    mp.set_property('ab-loop-b', to)
    mp.commandv('seek', from + 0.010, 'absolute')
    mp.set_property('pause', 'no')
    looping = true
    h.notify(string.format('循环: %.2f - %.2f', from, to), 'info', 3)
end

--- 循环中手动跳走或换文件时清除循环状态，避免区间残留。
return {
    play_till_sub_end = play_till_sub_end,
    play_till_next_sub_end = play_till_next_sub_end,
    sub_seek = sub_seek,
    sub_rewind = sub_rewind,
    toggle_sub_loop = toggle_sub_loop,
}
