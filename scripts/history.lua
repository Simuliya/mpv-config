-- Štěpán Němec <stepnem@smrk.net>
-- public domain
-- http://git.smrk.net/mpv-scripts/file/history.lua.html
-- Corrections and productive feedback appreciated, publicly
-- (<public@smrk.net>, inbox.smrk.net) or in private.
local mpu = require("mp.utils")
local sqlite3 = require("lsqlite3")

local history_db_path =
    mpu.join_path(os.getenv("XDG_DATA_HOME"), "mpv-history.sqlite")

local db = nil
local last_insert_id = nil

local function opendb()
  local d, errcode, errmsg = sqlite3.open(history_db_path)
  if not d then
    error(
      ("Failed to open %s: %d (%s)"):format(history_db_path, errcode, errmsg)
    )
  end

  db = d

  local sql = [[
    CREATE TABLE IF NOT EXISTS loaded_items(
      id	INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
      path	TEXT NOT NULL,
      filename	TEXT NOT NULL,
      title	TEXT NOT NULL,
      time_pos	REAL,
      date	DATE NOT NULL
    );
  ]]

  if db:exec(sql) ~= sqlite3.OK then
    error(("sqlite: %d (%s)"):format(db:errcode(), db:errmsg()))
  end
end

local function dbexec(sql, func, udata)
  if not db then
    opendb()
  end
  if db:exec(sql, func, udata) ~= sqlite3.OK then
    error(("sqlite: %d (%s)"):format(db:errcode(), db:errmsg()))
  end
end

local function abspath()
  local path = mp.get_property("path")
  if path:find("://") then
    return path
  else
    return mpu.join_path(mp.get_property("working-directory"), path)
  end
end

mp.register_event("file-loaded", function()
  dbexec(
    ([=[
      INSERT INTO loaded_items (path, filename, title, date)
      VALUES(
        "%s",
        "%s",
        "%s",
        unixepoch()
      );
      SELECT LAST_INSERT_ROWID();
    ]=]):format(
      abspath(),
      mp.get_property("filename"),
      mp.get_property("media-title")
    ),
    function(_udata, _cols, values, _names)
      last_insert_id = values[1]
      return 0
    end,
    nil
  )
end)

mp.add_hook("on_unload", 50, function(_hook)
  local timepos = mp.get_property("audio-pts") or mp.get_property("time-pos")
  if timepos then
    dbexec(([=[
      UPDATE loaded_items
      SET time_pos = %g
      WHERE id = %d;
    ]=]):format(timepos, last_insert_id))
  end
end)

mp.register_event("shutdown", function()
  if db then
    db:close()
  end
end)

mp.add_key_binding("ctrl+r", "history-resume", function()
  dbexec(
    ([=[
      SELECT time_pos FROM loaded_items
      WHERE time_pos NOTNULL AND title = "%s"
      ORDER BY date DESC
      LIMIT 1;
    ]=]):format(mp.get_property("media-title")),
    function(_udata, _cols, values, _names)
      if values[1] then
        mp.commandv("seek", values[1], "absolute", "exact")
      end
      return 0
    end,
    nil
  )
end)

mp.add_key_binding("alt+r", "play-recent", function()
  local items = {}
  dbexec(
    [[
      SELECT DISTINCT path, title FROM loaded_items
      ORDER BY date DESC;
    ]],
    function(_udata, _cols, values, _names)
      if values[1] then
        items[#items + 1] = values[1] .. "\x1f" .. values[2]
      end
      return 0
    end,
    nil
  )
  if items[1] then
    local dmenu = mp.command_native({
      name = "subprocess",
      args = { "dmenu", "-l", "20" },
      capture_stdout = true,
      playback_only = false,
      stdin_data = table.concat(items, "\n"),
    })
    if dmenu.status == 0 then
      mp.commandv(
        "loadfile",
        dmenu.stdout:sub(1, dmenu.stdout:find("\x1f") - 1)
      )
    end
  end
end)