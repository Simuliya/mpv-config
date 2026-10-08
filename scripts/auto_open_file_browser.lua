-- 播放列表播完后自动弹出 uosc 文件浏览器,并定位到最后播放的文件夹
--
-- 背景:mpv 把打开的文件夹当作播放列表,播完最后一个文件后进入 idle(待机)。
-- 同时 uosc 会在 end-file 时把当前路径清空(uosc/main.lua 的 end-file 处理),
-- 于是 idle 状态下 script-binding uosc/open-file 会回退到 default_directory(~/),
-- 表现为"播完跳到默认目录",无法方便地选择下一季的文件夹。
--
-- 本脚本:
--   1. 记住最后播放文件所在目录;
--   2. 仅当"整个播放列表自然播完"(最后一个是 eof,而非手动停止)进入 idle 时触发;
--   3. 触发前把 uosc 的 default_directory 在运行时改成该目录,再弹出文件浏览器。
-- 配置(如 idle_call_menu)完全不动。

local mp = require 'mp'
local utils = require 'mp.utils'

local last_dir = nil      -- 最后播放文件所在目录(带结尾分隔符)
local had_media = false   -- 本次会话是否播放过(用于区分"开机空闲")
local ended_by_eof = false -- 最近一次 end-file 是否为自然播放结束

-- 从文件路径取出所在目录(带结尾分隔符);协议/空路径返回 nil
local function dir_of(path)
	if not path or path == '' or path:find('://') then return nil end
	local dir = utils.split_path(path)
	if not dir or dir == '' then return nil end
	return dir
end

mp.register_event('file-loaded', function()
	had_media = true
	ended_by_eof = false
	last_dir = dir_of(mp.get_property('path')) or last_dir
end)

mp.register_event('end-file', function(ev)
	-- 'eof' = 自然播放结束;'stop'/'quit'/'error' 等不算"播完"
	ended_by_eof = (ev.reason == 'eof')
end)

-- 运行时把 uosc 的 default_directory 指向指定目录
-- 依据:mpv >= 0.38 的 mp.options.read_options 支持 on_update,
--       uosc 通过 read_options(options, nil, handle_options) 使用该特性,
--       改 script-opts 会实时通知 uosc 并更新其 options.default_directory。
local function set_uosc_default_dir(dir)
	local ok, err = pcall(function()
		local parts = {}
		-- 保留除 uosc-default_directory 之外的既有脚本选项
		for item in (mp.get_property('script-opts') or ''):gmatch('[^,]+') do
			if not item:match('^%s*uosc%-default_directory%s*=') then
				parts[#parts + 1] = item
			end
		end
		parts[#parts + 1] = 'uosc-default_directory=' .. dir
		mp.set_property('script-opts', table.concat(parts, ','))
	end)
	if not ok then
		mp.msg.warn('set uosc default_directory failed: ' .. tostring(err))
	end
end

mp.observe_property('idle-active', 'bool', function(_, idle)
	if not idle then return end
	-- 只有"播放过"且"是自然播完"才弹;开机空闲、手动停止都不弹
	if not (had_media and ended_by_eof) then
		had_media = false
		return
	end
	had_media = false

	mp.add_timeout(0.2, function()
		if last_dir then set_uosc_default_dir(last_dir) end
		-- 再等一小会,让 uosc 应用新的默认目录
		mp.add_timeout(0.05, function()
			mp.command('script-binding uosc/open-file')
		end)
	end)
end)
