-- fastforward.lua
--
-- Skipping forward by five seconds can be jarring.
--
-- This script allows you to tap or hold the RIGHT key to speed up video,
-- the faster you tap RIGHT the faster the video will play. After a specified
-- decay delay, the playback speed will begin to decrease back to 1x speed.

local decay_delay = .05 -- rate of time by which playback speed is decreased
local speed_increments = .2 -- amount by which playback speed is increased each time
local speed_decrements = .4 -- amount by which playback speed is decreased each time
local max_rate = 3 -- will not exceed this rate
local inertial_decay = false -- changes the behavior of speed decay
local quick_seek_time = 5 -- time to seek forward in seconds on single press

local mp = require 'mp'
local auto_dec_timer = nil -- 自动减速的计时器
local osd_duration = math.max(decay_delay, mp.get_property_number("osd-duration")/1000) -- OSD 显示时间
local key_down_time = nil -- 记录按键按下的时间
local long_press_threshold = 0.5 -- 判断长按的时间阈值

-- 增加播放速度
local function inc_speed()
    -- 如果已有减速计时器，停止它
    if auto_dec_timer ~= nil then
        auto_dec_timer:kill()
    end

    -- 获取当前播放速度并增加
    local new_speed = mp.get_property("speed") + speed_increments

    -- 确保播放速度不超过最大值
    if new_speed > max_rate - speed_increments then
        new_speed = max_rate
    end

    -- 设置新的播放速度并显示 OSD
    mp.set_property("speed", new_speed)
    mp.osd_message(("▶▶ x%.1f"):format(new_speed), osd_duration)
end

-- 启动自动减速
local function auto_dec_speed()
    auto_dec_timer = mp.add_periodic_timer(decay_delay, dec_speed)
end

-- 减少播放速度
function dec_speed()
    -- 获取当前播放速度并减少
    local new_speed = mp.get_property("speed") - speed_decrements
    if new_speed < 1 + speed_decrements then
        new_speed = 1
        if auto_dec_timer ~= nil then auto_dec_timer:kill() end
    end

    -- 设置新的播放速度并显示 OSD
    mp.set_property("speed", new_speed)
    mp.osd_message(("▶▶ x%.1f"):format(new_speed), osd_duration)
end

-- 处理按键事件
local function fastforward_handle(event)
    if event.event == "down" then
        -- 记录按键按下的时间
        key_down_time = mp.get_time()
    elseif event.event == "repeat" then
        -- 如果是长按或重复按键事件，增加播放速度
        inc_speed()
        if inertial_decay then
            mp.add_timeout(decay_delay, dec_speed)
        end
    elseif event.event == "up" then
        local key_hold_time = mp.get_time() - key_down_time
        key_down_time = nil

        -- 如果按住时间少于阈值，则认为是单次按键，执行快进
        if key_hold_time < long_press_threshold then
            mp.commandv("seek", quick_seek_time, "relative+exact")
        elseif not inertial_decay then
            -- 否则启动自动减速
            auto_dec_speed()
        end
    end
end

-- 绑定 RIGHT 键到 fastforward_handle 函数
mp.add_forced_key_binding("RIGHT", "fastforward", fastforward_handle, {complex=true, repeatable=true})
