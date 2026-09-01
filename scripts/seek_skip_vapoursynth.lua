-- 拖动进度条或切换倍速时自动临时移除 vapoursynth 补帧滤镜，减少卡顿
-- 只移除 vapoursynth，保留其他滤镜（如弹幕的 @danmaku:fps），避免冲突
-- 用两个布尔标记（seek_active / speed_active）协调，任一激活即移除

local mp = require('mp')

local seek_timer = nil
local seek_active = false    -- seek 是否在暂停滤镜
local speed_active = false    -- 倍速是否在暂停滤镜
local saved_vs = nil         -- 保存的 vapoursynth 滤镜对象
local saved_idx = nil        -- 原位置索引

-- 在 vf 链中找 vapoursynth，返回 (是否找到, 位置)
local function find_vapoursynth(vf_list)
	if type(vf_list) ~= "table" then return false, nil end
	for i, f in ipairs(vf_list) do
		if f.name == "vapoursynth" then
			return true, i
		end
	end
	return false, nil
end

-- 根据当前两个标记的状态，移除或恢复 vapoursynth
local function apply_vf_state()
	local want_disable = seek_active or speed_active
	local vf_list = mp.get_property_native('vf')
	local has_vs, vs_idx = find_vapoursynth(vf_list)

	if want_disable then
		-- 需要禁用：vapoursynth 还在就移除它
		if has_vs then
			saved_vs = vf_list[vs_idx]
			saved_idx = vs_idx
			local remaining = {}
			for j, g in ipairs(vf_list) do
				if j ~= vs_idx then table.insert(remaining, g) end
			end
			mp.set_property_native('vf', remaining)
		end
	else
		-- 需要启用：有保存且当前不在，插回原位
		if saved_vs and not has_vs then
			if type(vf_list) == "table" then
				local idx = math.min(saved_idx or (#vf_list + 1), #vf_list + 1)
				table.insert(vf_list, idx, saved_vs)
				mp.set_property_native('vf', vf_list)
			end
		elseif has_vs then
			saved_vs = nil
			saved_idx = nil
		end
	end
end

-- Seek：激活暂停，1 秒后取消（连续拖动只重置计时器，不累加）
local function on_seek()
	seek_active = true
	apply_vf_state()
	if seek_timer then seek_timer:kill() end
	seek_timer = mp.add_timeout(1.0, function()
		seek_active = false
		apply_vf_state()
	end)
end

-- 倍速：speed != 1 时暂停，回到 1 时恢复
mp.observe_property('speed', 'native', function(_, speed)
	if speed == nil then return end
	local new_active = (speed ~= 1)
	if new_active ~= speed_active then
		speed_active = new_active
		apply_vf_state()
	end
end)

mp.register_event('seek', on_seek)