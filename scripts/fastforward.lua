-- fastforward.lua
--
-- 允许通过长按 RIGHT 键加速播放，松手后恢复到原来的播放速度。
-- 也支持短按 RIGHT 键进行快进（默认 5 秒）。
--

local decay_delay = .05 -- 速度减少的时间间隔
local speed_increments = .2 -- 速度每次增加的幅度
local max_rate = 3 -- 最大播放速度
local quick_seek_time = 5 -- 单次按键快进时间（秒）
local long_press_threshold = 0.5 -- 长按判断阈值（秒）

local mp = require 'mp'
local auto_dec_timer = nil
local osd_duration = math.max(decay_delay, mp.get_property_number("osd-duration") / 1000)

local key_down_time = nil -- 记录按键按下的时间
local original_speed = nil -- 记录松手前的播放速度（修正：不设默认值）

-- 增加播放速度
local function inc_speed()
    if auto_dec_timer ~= nil then
        auto_dec_timer:kill()
    end

    -- 在 **每次加速前** 记录当前播放速度
    if original_speed == nil then
        original_speed = mp.get_property_number("speed")
    end

    local new_speed = mp.get_property_number("speed") + speed_increments
    if new_speed > max_rate - speed_increments then
        new_speed = max_rate
    end

    mp.set_property("speed", new_speed)
    mp.osd_message(("▶▶ x%.1f"):format(new_speed), osd_duration)
end

-- 恢复原来的播放速度
local function restore_speed()
    if original_speed then
        mp.set_property("speed", original_speed)
        mp.osd_message(("▶▶ x%.1f"):format(original_speed), osd_duration)
    end
    original_speed = nil --松手后清空 original_speed
end

-- 处理按键事件
local function fastforward_handle(event)
    if event.event == "down" then
        key_down_time = mp.get_time()

        -- 按键按下时记录当前播放速度，避免误差
        if original_speed == nil then
            original_speed = mp.get_property_number("speed")
        end
    elseif event.event == "repeat" then
        inc_speed()
    elseif event.event == "up" then
        local key_hold_time = mp.get_time() - key_down_time
        key_down_time = nil

        if key_hold_time < long_press_threshold then
            -- 短按执行快进
            mp.commandv("seek", quick_seek_time, "relative+exact")
        else
            -- 松手后恢复原速
            restore_speed()
        end
    end
end

-- 绑定 RIGHT 键
mp.add_forced_key_binding("RIGHT", "fastforward", fastforward_handle, {complex = true, repeatable = true})
