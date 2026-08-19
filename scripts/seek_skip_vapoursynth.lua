-- 拖动进度条时自动临时关闭视频滤镜，减少补帧卡顿
-- 逻辑：检测到 seek 事件 → 清空 vf → 1 秒后恢复
-- 使用 native 属性保证滤镜链完整还原

local mp = require('mp')

local seek_timer = nil
local saved_vf = nil
local disabled = false

local function on_seek()
    -- 只在还没关闭时保存当前滤镜链并清空
    if not disabled then
        saved_vf = mp.get_property_native('vf')
        mp.set_property_native('vf', {})
        disabled = true
    end

    -- 重置计时器：连续拖动时重新计 1 秒
    if seek_timer then seek_timer:kill() end
    seek_timer = mp.add_timeout(1.0, function()
        if saved_vf then
            mp.set_property_native('vf', saved_vf)
        end
        saved_vf = nil
        disabled = false
    end)
end

mp.register_event('seek', on_seek)