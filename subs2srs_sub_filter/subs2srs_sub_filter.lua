--[[
    subs2srs_sub_filter.lua

    位置： portable_config/subs2srs_sub_filter/subs2srs_sub_filter.lua
    作用： mpvacious 在「复制到剪贴板」和「导出到 Anki」之前会调用 preprocess()。
           双语字幕一般是「中文一行、外文一行」换行排列，
           这里逐行判断，把中文行剔掉，只留外文行（日文 / 英文）。
    启用： subs2srs.conf 里 custom_sub_filter_enabled=yes，然后重启 mpv。
]]

local M = {}

--------------------------------------------------------------------------
-- 可调项
--------------------------------------------------------------------------

-- 'foreign' = 只留外文行（默认，你要的效果）
-- 'zh'      = 反过来只留中文行
M.keep = 'foreign'

-- 是否去掉 ASS 样式标签（{\pos(...)}、{\an8} 之类），避免复制进剪贴板
M.strip_ass_tags = true

--------------------------------------------------------------------------
-- 内部：字符区间（UTF-8 字节匹配）
--------------------------------------------------------------------------

-- 假名 U+3040-U+30FF（平假名 / 片假名）。日文句子必然含假名。
local KANA = '\227[\129-\131][\128-\191]'

-- CJK 汉字。中文行必然含汉字。
local HAN = '[\228-\233][\128-\191][\128-\191]'

-- 拉丁字母（英文等）
local LATIN = '[%a]'

local function has_kana(s)  return s:find(KANA)  ~= nil end
local function has_han(s)   return s:find(HAN)   ~= nil end
local function has_latin(s) return s:find(LATIN) ~= nil end

--- 逐行分类：
---   'zh'      - 含汉字且不含假名  → 中文行
---   'foreign' - 含假名（日文），或含拉丁字母且无汉字（英文等） → 外文行
---   'unknown' - 其余（纯符号、纯数字等），不参与判断
local function classify(line)
    if has_han(line) and not has_kana(line) then
        return 'zh'
    end
    if has_kana(line) then
        return 'foreign'
    end
    if has_latin(line) and not has_han(line) then
        return 'foreign'
    end
    return 'unknown'
end

--------------------------------------------------------------------------
-- 内部：文本处理
--------------------------------------------------------------------------

local function strip_ass_tags(s)
    -- ASS 覆写块一定以 {\ 开头（如 {\pos(320,240)} 、{\an8}），以此精确匹配，
    -- 避免把文本里转义的字面量 \{ \} 误当成标签。
    s = s:gsub('{\\[^}]*}', '')
    -- 反转义文本中的字面花括号
    s = s:gsub('\\{', '{'):gsub('\\}', '}')
    return s
end

--- 按换行切分。ASS 的硬换行 \N（以及 \n）也算换行。
local function split_lines(text)
    text = text:gsub('\\N', '\n'):gsub('\\n', '\n')
    local lines = {}
    for line in text:gmatch('[^\r\n]+') do
        if line:match('%S') then
            lines[#lines + 1] = line
        end
    end
    return lines
end

--------------------------------------------------------------------------
-- 入口
--------------------------------------------------------------------------

M.preprocess = function(text)
    if not text or text == '' then
        return text
    end

    local lines = split_lines(text)

    -- 单行不动：无法判断是否双语，且避免把唯一一句删成空
    if #lines < 2 then
        return text
    end

    -- 用于判断的行（剥掉样式标签后再分类）
    local classified = {}
    local n_zh, n_foreign = 0, 0
    for i, line in ipairs(lines) do
        local probe = M.strip_ass_tags and strip_ass_tags(line) or line
        local kind = classify(probe)
        classified[i] = kind
        if kind == 'zh' then
            n_zh = n_zh + 1
        elseif kind == 'foreign' then
            n_foreign = n_foreign + 1
        end
    end

    -- 只有确实同时存在「中文行」和「外文行」时才过滤。
    -- 纯中文字幕、纯外文字幕、单语片源都不会被改动。
    if n_zh == 0 or n_foreign == 0 then
        return text
    end

    local drop = (M.keep == 'foreign') and 'zh' or 'foreign'

    local kept = {}
    for i, line in ipairs(lines) do
        if classified[i] ~= drop then
            if M.strip_ass_tags then
                line = strip_ass_tags(line)
            end
            if line:match('%S') then
                kept[#kept + 1] = line
            end
        end
    end

    -- 全被剔除说明判断有误，退回原文
    if #kept == 0 then
        return text
    end

    return table.concat(kept, '\n')
end

return M