-- Nightswim desktop widgets for conky: GitHub contributions, calendar,
-- checklist (checklist.lua), system.
-- Colours mirror nightswim/palette.sh. Data for the GitHub card comes from
-- gh-contrib.py (cached in ~/.cache/nightswim/gh-contrib.txt).
-- The conky AppImage bakes its build directory into package.cpath; point it
-- at the mounted AppDir so the bundled cairo bindings resolve.
if os.getenv('APPDIR') then
  package.cpath = os.getenv('APPDIR') .. '/usr/lib/conky/lib?.so;' .. package.cpath
end
require 'cairo'
pcall(require, 'cairo_xlib')

local HERE = debug.getinfo(1, 'S').source:match('^@(.*/)') or './'
local CACHE = os.getenv('HOME') .. '/.cache/nightswim/gh-contrib.txt'
local FONT = 'Adwaita Sans'
local ICON_FONT = '0xProto Nerd Font'

local function hex(h, a)
  return tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255,
         tonumber(h:sub(5, 6), 16) / 255, a or 1
end
local C = {
  card = { hex('0e1328', 0.80) }, edge = { hex('9a8cc8', 0.16) },
  fg = { hex('d6cfe8') }, bright = { hex('e6e0f2') }, dim = { hex('6b6f9a') },
  gold = 'e8a95b', lilac = { hex('9a8cc8') }, cyan = { hex('8cc4d4') },
  pink = { hex('d79bc9') }, green = { hex('86b3a0') }, track = { hex('2a2f55', 0.85) },
}
local LEVEL_ALPHA = { [1] = 0.35, [2] = 0.55, [3] = 0.8, [4] = 1.0 }

local function rgba(cr, c) cairo_set_source_rgba(cr, c[1], c[2], c[3], c[4]) end

local function rrect(cr, x, y, w, h, r)
  cairo_new_sub_path(cr)
  cairo_arc(cr, x + w - r, y + r, r, -math.pi / 2, 0)
  cairo_arc(cr, x + w - r, y + h - r, r, 0, math.pi / 2)
  cairo_arc(cr, x + r, y + h - r, r, math.pi / 2, math.pi)
  cairo_arc(cr, x + r, y + r, r, math.pi, 3 * math.pi / 2)
  cairo_close_path(cr)
end

local function card(cr, x, y, w, h)
  rrect(cr, x, y, w, h, 18); rgba(cr, C.card); cairo_fill_preserve(cr)
  cairo_set_line_width(cr, 1); rgba(cr, C.edge); cairo_stroke(cr)
end

local function font(cr, size, o)
  cairo_select_font_face(cr, o.font or FONT, CAIRO_FONT_SLANT_NORMAL,
    o.bold and CAIRO_FONT_WEIGHT_BOLD or CAIRO_FONT_WEIGHT_NORMAL)
  cairo_set_font_size(cr, size)
end

local function measure(cr, s, size, o)
  font(cr, size, o or {})
  local ext = cairo_text_extents_t:create()
  cairo_text_extents(cr, s, ext)
  return ext.x_advance
end

-- text(cr, s, x, y, size, colour, {bold=, align='l'|'r'|'c', font=})
local function text(cr, s, x, y, size, c, o)
  o = o or {}
  local adv = measure(cr, s, size, o)
  if o.align == 'r' then x = x - adv elseif o.align == 'c' then x = x - adv / 2 end
  cairo_move_to(cr, x, y); rgba(cr, c); cairo_show_text(cr, s)
  return adv
end

-- Nerd Font glyph (codepoint) centred on cx, cy by its ink box.
local function icon(cr, cp, cx, cy, size, c)
  local s = utf8.char(cp)
  font(cr, size, { font = ICON_FONT })
  local ext = cairo_text_extents_t:create()
  cairo_text_extents(cr, s, ext)
  cairo_move_to(cr, cx - ext.x_bearing - ext.width / 2, cy - ext.y_bearing - ext.height / 2)
  rgba(cr, c); cairo_show_text(cr, s)
end

-- Shorten s with an ellipsis until it fits in maxw.
local function fit(cr, s, size, maxw, o)
  if measure(cr, s, size, o) <= maxw then return s end
  local n = utf8.len(s) or #s
  while n > 0 do
    n = n - 1
    local t = s:sub(1, (utf8.offset(s, n + 1) or #s + 1) - 1) .. '…'
    if measure(cr, t, size, o) <= maxw then return t end
  end
  return '…'
end

local function cell(cr, x, y, s, level)
  rrect(cr, x, y, s, s, 2.5)
  if level and level > 0 then
    cairo_set_source_rgba(cr, hex(C.gold, LEVEL_ALPHA[level]))
  else
    rgba(cr, C.track)
  end
  cairo_fill(cr)
end

-- GitHub contributions -----------------------------------------------------
local function read_contrib()
  local f = io.open(CACHE)
  if not f then return nil end
  local head = f:read('*l') or ''
  local login, total, synced = head:match('^(%S+) (%d+) (%S+)')
  local weeks = {}
  for line in f:lines() do
    local date, days = line:match('^(%d+%-%d+%-%d+) (%S+)$')
    if date then weeks[#weeks + 1] = { date = date, days = days } end
  end
  f:close()
  return login and { login = login, total = total, synced = synced, weeks = weeks }
end

local MONTHS = { 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' }

local function github(cr, x, y, w, h)
  card(cr, x, y, w, h)
  local d = read_contrib()
  local p = 18
  text(cr, '\u{f09b}', x + p, y + 32, 17, C.bright, { font = ICON_FONT })
  if not d then
    text(cr, 'GitHub', x + p + 26, y + 31, 14, C.bright, { bold = true })
    text(cr, 'waiting for gh-contrib.py…', x + p, y + h / 2 + 6, 13, C.dim)
    return
  end
  text(cr, d.login, x + p + 26, y + 31, 14, C.bright, { bold = true })
  text(cr, d.total .. ' contributions', x + w - p, y + 31, 12, C.fg, { align = 'r', bold = true })

  local s, gap = 10, 3
  local gx, gy = x + 52, y + 66
  local last_month
  for i, wk in ipairs(d.weeks) do
    local cx = gx + (i - 1) * (s + gap)
    local m = tonumber(wk.date:sub(6, 7))
    -- Label a month at the first full week that starts in it.
    if m ~= last_month and tonumber(wk.date:sub(9, 10)) <= 7 and i < #d.weeks - 1 then
      text(cr, MONTHS[m], cx, gy - 9, 11, C.fg, { bold = true })
    end
    last_month = m
    for day = 1, 7 do
      local ch = wk.days:sub(day, day)
      if ch ~= '.' then cell(cr, cx, gy + (day - 1) * (s + gap), s, tonumber(ch)) end
    end
  end
  for row, name in pairs({ [1] = 'Mon', [3] = 'Wed', [5] = 'Fri' }) do
    text(cr, name, x + p, gy + row * (s + gap) + 9, 10.5, C.fg, { bold = true })
  end

  local fy = y + h - 18
  text(cr, 'Synced ' .. d.synced, x + p, fy, 11, C.dim, { bold = true })
  local more = text(cr, 'More', x + w - p, fy, 11, C.dim, { bold = true, align = 'r' })
  local lx = x + w - p - more - 6 - 5 * (s + gap)
  for lvl = 0, 4 do cell(cr, lx + lvl * (s + gap), fy - s + 1, s, lvl) end
  text(cr, 'Less', lx - 6, fy, 11, C.dim, { bold = true, align = 'r' })
end

-- Calendar -------------------------------------------------------------------
local function calendar(cr, x, y, w, h)
  card(cr, x, y, w, h)
  local now = os.date('*t')
  local p = 20
  text(cr, os.date('%A'):upper(), x + p, y + 36, 12, { hex(C.gold) }, { bold = true })
  text(cr, tostring(now.day), x + p - 3, y + 112, 72, C.bright, { bold = true })
  text(cr, os.date('Day %j · Week %V'):gsub('Day 0+', 'Day '), x + p, y + h - 20, 12, C.dim, { bold = true })

  local cx0, colw = x + 176, 26
  text(cr, os.date('%B'):upper(), x + 176, y + 36, 12, { hex(C.gold) }, { bold = true })
  for i, l in ipairs({ 'S', 'M', 'T', 'W', 'T', 'F', 'S' }) do
    text(cr, l, cx0 + (i - 0.5) * colw, y + 58, 11, C.dim, { bold = true, align = 'c' })
  end
  local first = os.time({ year = now.year, month = now.month, day = 1, hour = 12 })
  local offset = tonumber(os.date('%w', first))
  local days = os.date('*t', os.time({ year = now.year, month = now.month + 1, day = 0, hour = 12 })).day
  local rowh = (h - 76) / 6
  for dnum = 1, days do
    local idx = offset + dnum - 1
    local col, row = idx % 7, math.floor(idx / 7)
    local tx, ty = cx0 + (col + 0.5) * colw, y + 80 + row * rowh
    if dnum == now.day then
      cairo_arc(cr, tx, ty - 4.5, 10, 0, 2 * math.pi)
      cairo_set_source_rgba(cr, hex(C.gold)); cairo_fill(cr)
      text(cr, tostring(dnum), tx, ty, 12, { hex('0e1328') }, { bold = true, align = 'c' })
    else
      text(cr, tostring(dnum), tx, ty, 12, C.fg, { bold = true, align = 'c' })
    end
  end
end

-- System -----------------------------------------------------------------------
local function bar(cr, x, y, w, frac, c)
  rrect(cr, x, y, w, 8, 4); rgba(cr, C.track); cairo_fill(cr)
  frac = math.max(0, math.min(1, frac))
  if frac > 0 then rrect(cr, x, y, math.max(8, w * frac), 8, 4); rgba(cr, c); cairo_fill(cr) end
end

-- Battery glyph for the charge level / state in /sys (md-battery_*).
local function battery_icon(pct)
  local f = io.open('/sys/class/power_supply/BAT0/status')
  local status = f and f:read('*l') or ''
  if f then f:close() end
  if status == 'Charging' then return 0xf0084 end
  if pct >= 95 or status == 'Full' then return 0xf0079 end
  if pct < 5 then return 0xf0083 end
  return 0xf007a + math.max(0, math.min(8, math.floor(pct / 10) - 1))
end

local function system(cr, x, y, w, h)
  card(cr, x, y, w, h)
  local p = 20
  icon(cr, 0xf0379, x + p + 7, y + 31, 15, { hex(C.gold) })               -- md-monitor
  text(cr, 'SYSTEM', x + p + 22, y + 36, 12, { hex(C.gold) }, { bold = true })
  local up = text(cr, 'up ' .. conky_parse('${uptime_short}'), x + w - p, y + 36, 12, C.dim,
    { bold = true, align = 'r' })
  icon(cr, 0xf0150, x + w - p - up - 11, y + 31.5, 13, C.dim)            -- md-clock_outline
  local battery = tonumber(conky_parse('${battery_percent BAT0}')) or 0
  local rows = {
    { 0xf061a, 'CPU', tonumber(conky_parse('${cpu cpu0}')) or 0, C.lilac },     -- md-chip
    { 0xf035b, 'RAM', tonumber(conky_parse('${memperc}')) or 0, C.cyan },       -- md-memory
    { 0xf02ca, 'Disk', tonumber(conky_parse('${fs_used_perc /}')) or 0, C.pink }, -- md-harddisk
    { battery_icon(battery), 'Battery', battery, C.green },
  }
  local top, step = y + 70, (h - 92) / (#rows - 1)
  for i, r in ipairs(rows) do
    local ry = top + (i - 1) * step
    local c = r[4]
    rrect(cr, x + p, ry - 17, 24, 24, 7); cairo_set_source_rgba(cr, c[1], c[2], c[3], 0.16); cairo_fill(cr)
    icon(cr, r[1], x + p + 12, ry - 5, 14, c)
    text(cr, r[2], x + p + 34, ry, 12.5, C.fg, { bold = true })
    bar(cr, x + p + 100, ry - 8, w - 2 * p - 100 - 50, r[3] / 100, c)
    text(cr, string.format('%d%%', r[3]), x + w - p, ry, 12.5, C.bright, { bold = true, align = 'r' })
  end
end

-- Checklist ----------------------------------------------------------------------
local checklist = dofile(HERE .. 'checklist.lua')({
  C = C, hex = hex, rgba = rgba, rrect = rrect, card = card, text = text, icon = icon,
  fit = fit, measure = measure, MONTHS = MONTHS,
})
local CHECKLIST = { 1, 213, 420, 196 }
local dx            -- drawing offset applied by cairo_translate below
local region_dx     -- offset the window's input region was last set for

-- conky makes the window click-through; give it an input region over the
-- checklist card (re-applied when the drawing offset moves the card).
local function claim_input()
  if region_dx == dx then return end
  region_dx = dx
  local r = CHECKLIST
  os.execute(string.format("python3 '%sinput-region.py' %d %d %d %d >/dev/null 2>&1 &",
    HERE, r[1] + dx, r[2], r[3], r[4]))
end

function conky_nightswim_mouse(ev)
  if not dx then return false end
  return checklist.mouse(ev, dx)
end

-- Layout (window is 812×412; see conky.conf) ---------------------------------
function conky_nightswim()
  if conky_window == nil then return end
  -- Refresh the GitHub cache every 30 minutes in conky's own thread.
  conky_parse('${texeci 1800 python3 ' .. HERE .. 'gh-contrib.py}')
  local cs = cairo_xlib_surface_create(conky_window.display, conky_window.drawable,
    conky_window.visual, conky_window.width, conky_window.height)
  local cr = cairo_create(cs)
  cairo_set_antialias(cr, CAIRO_ANTIALIAS_BEST)
  -- Text scaling (Xft.dpi > 96) makes conky widen the window past 812; keep
  -- the cards flush with its right edge so the gap_x margin still holds.
  dx = math.max(0, conky_window.width - 812)
  cairo_translate(cr, dx, 0)
  github(cr, 1, 1, 420, 200)
  calendar(cr, 433, 1, 378, 200)
  checklist.draw(cr, table.unpack(CHECKLIST))
  system(cr, 433, 213, 378, 196)
  cairo_destroy(cr)
  cairo_surface_destroy(cs)
  claim_input()
end
