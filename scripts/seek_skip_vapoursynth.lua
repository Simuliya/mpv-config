-- 拖动进度条或切换倍速时自动临时关闭视频滤镜，减少补帧卡顿
-- 逻辑：seek / 倍速变化 → 清空 vf → 恢复条件满足后还原
-- 使用引用计数协调多个机制同时触发

local mp = require('mp')

local seek_timer = nil
local saved_vf = nil
local disabled_count = 0
local speed_prev = nil

local function disable_vf()
    if disabled_count == 0 then
        saved_vf = mp.get_property_native('vf')
        mp.set_property_native('vf', {})
    end
    disabled_count = disabled_count + 1
end

local function enable_vf()
    disabled_count = disabled_count - 1
    if disabled_count <= 0 then
        disabled_count = 0
        if saved_vf then
            mp.set_property_native('vf', saved_vf)
            saved_vf = nil
        end
    end
end

-- Seek: 清空 vf，1 秒后恢复
local function on_seek()
    disable_vf()
    if seek_timer then seek_timer:kill() end
    seek_timer = mp.add_timeout(1.0, function()
        enable_vf()
    end)
end

-- 倍速: speed != 1 时清空 vf，回到 1 时恢复
mp.observe_property('speed', 'native', function(_, speed)
    if speed == nil then return end
    if speed_prev == nil then
        speed_prev = speed
        return
    end
    if speed_prev == 1 and speed ~= 1 then
        disable_vf()
    elseif speed_prev ~= 1 and speed == 1 then
        enable_vf()
    end
    speed_prev = speed
end)

mp.register_event('seek', on_seek)