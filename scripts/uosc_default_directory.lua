-- 让 uosc 文件浏览器默认从"系统的视频文件夹"开始
--
-- 背景:uosc 的 default_directory 目前被设为 ~/(用户主目录),没有正在播放的文件时
-- 文件浏览器就从主目录开始。用户希望默认从 Windows 的"视频"文件夹开始,且该文件夹
-- 可以被用户移动到别的盘,所以要跟随系统设置(读注册表已知文件夹位置),不能写死盘符。
--
-- 与 auto_open_file_browser.lua 的关系:
--   本脚本只在启动时把默认目录设为"视频"文件夹(命令行层的运行时覆盖);
--   auto_open_file_browser.lua 在"播完"那一刻把它改成最后播放的文件夹(同一处,优先级
--   更高,仅本次会话生效)。下次启动本脚本再把默认设回"视频"文件夹,两者共存。

local mp = require 'mp'

-- 展开 %VAR% 形式的环境变量
local function expand_env(s)
	return (s:gsub('%%([%w_]+)%%', function(v) return os.getenv(v) or ('%' .. v .. '%') end))
end

-- 解析 Windows"视频"已知文件夹位置(会随用户"移动文件夹"更新)
local function system_videos_dir()
	if mp.get_property('platform') ~= 'windows' then return nil end

	local ok, res = pcall(function()
		return mp.command_native({
			name = 'subprocess',
			args = {
				'reg', 'query',
				'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\User Shell Folders',
				'/v', 'My Video',
			},
			capture_stdout = true,
			capture_stderr = true,
			playback_only = false,
		})
	end)

	if ok and res and res.status == 0 and res.stdout then
		-- 输出形如:  "    My Video    REG_EXPAND_SZ    E:\Videos"
		-- 按行尾整段取路径,兼容含空格的路径
		local p = res.stdout:match('REG_EXPAND_SZ%s+(.+)') or res.stdout:match('REG_SZ%s+(.+)')
		if p then
			p = expand_env((p:gsub('[\r\n]+$', ''):gsub('%s+$', '')))
			if p ~= '' then return p end
		end
	end

	-- 兜底
	local up = os.getenv('USERPROFILE')
	if up then return up .. '\\Videos' end
	return nil
end

-- 通过运行时改 script-opts 设置 uosc 的默认目录(uosc 使用 read_options 的 on_update,
-- mpv >= 0.38,uosc/main.lua 已注册,改后会实时更新其 options.default_directory)
local function set_uosc_default_dir(dir)
	local ok, err = pcall(function()
		local parts = {}
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

local dir = system_videos_dir()
if dir then
	set_uosc_default_dir(dir)
	mp.msg.verbose('uosc default_directory -> ' .. dir)
end
