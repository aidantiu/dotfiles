-- Checklist card for the Nightswim conky widgets.
--
-- Items live in ~/.local/share/nightswim/checklist.txt, one "[ ] text" or
-- "[x] text" per line (hand edits are picked up on the next redraw).
-- Archived items move to checklist-archive.txt as "YYYY-MM-DD [x] text".
--
-- Mouse (via conky's lua_mouse_hook; input-region.py makes the card clickable):
--   box          tick / untick
--   row          select it (left or right click): move up/down, edit,
--                archive, delete (click twice); in the archive: restore, delete
--   double-click edit
--   wheel        scroll when the list is longer than the card
--   header       + add · archive view · sweep (archive every ticked item)
-- Text entry goes through a zenity prompt; its reply is picked up on redraw.
return function(ui)
  local C, hex, rgba, rrect, card, text, icon, fit =
    ui.C, ui.hex, ui.rgba, ui.rrect, ui.card, ui.text, ui.icon, ui.fit

  local HOME = os.getenv('HOME')
  local DATA = (os.getenv('XDG_DATA_HOME') or HOME .. '/.local/share') .. '/nightswim'
  local LIST, ARCHIVE = DATA .. '/checklist.txt', DATA .. '/checklist-archive.txt'
  local REPLY = (os.getenv('XDG_RUNTIME_DIR') or '/tmp') .. '/nightswim-checklist.reply'

  -- md-* Nerd Font codepoints
  local G = {
    list = 0xf0756, add = 0xf0415, archive = 0xf003c, back = 0xf004d, sweep = 0xf00e2,
    check = 0xf0e1e, up = 0xf005d, down = 0xf0045, edit = 0xf03eb, stow = 0xf1259,
    delete = 0xf09e7, restore = 0xf099b,
  }
  local ROWS, RH = 5, 25
  local FAST = 0.2        -- redraw interval while a click or prompt is in flight
  local DOUBLE_MS = 450

  local function q(s) return "'" .. s:gsub("'", "'\\''") .. "'" end
  os.execute('mkdir -p ' .. q(DATA))
  os.remove(REPLY)

  -- Storage ----------------------------------------------------------------
  local function read_lines(path)
    local out, f = {}, io.open(path)
    if not f then return out end
    for line in f:lines() do out[#out + 1] = line end
    f:close()
    return out
  end

  local function write_lines(path, lines)
    local tmp = path .. '.tmp'
    local f = io.open(tmp, 'w')
    if not f then return end
    for _, l in ipairs(lines) do f:write(l, '\n') end
    f:close()
    os.rename(tmp, path)
  end

  local function fmt(it) return (it.done and '[x] ' or '[ ] ') .. it.text end

  local function load_list()
    local items = {}
    for _, line in ipairs(read_lines(LIST)) do
      local mark, rest = line:match('^%[([ xX])%]%s?(.*)$')
      local t = (rest or line):match('^%s*(.-)%s*$')
      if t ~= '' then items[#items + 1] = { done = mark ~= nil and mark ~= ' ', text = t } end
    end
    return items
  end

  local function save_list(items)
    local lines = {}
    for i, it in ipairs(items) do lines[i] = fmt(it) end
    write_lines(LIST, lines)
  end

  -- Newest first on screen; stored oldest first so archiving is an append.
  local function load_archive()
    local items = {}
    for _, line in ipairs(read_lines(ARCHIVE)) do
      local date, mark, t = line:match('^(%d%d%d%d%-%d%d%-%d%d) %[([ xX])%]%s?(.*)$')
      if date then table.insert(items, 1, { date = date, done = mark ~= ' ', text = t }) end
    end
    return items
  end

  local function save_archive(items)
    local lines = {}
    for i = #items, 1, -1 do lines[#lines + 1] = items[i].date .. ' ' .. fmt(items[i]) end
    write_lines(ARCHIVE, lines)
  end

  local function append_archive(items)
    if #items == 0 then return end
    local f = io.open(ARCHIVE, 'a')
    if not f then return end
    local today = os.date('%Y-%m-%d')
    for _, it in ipairs(items) do f:write(today, ' ', fmt(it), '\n') end
    f:close()
  end

  -- Apply fn(items, i) to the item the user clicked, re-reading the file first
  -- so hand edits made since the last redraw aren't clobbered. If the row moved,
  -- fall back to the first item with the same text.
  local function mutate(loader, saver, idx, text_at_click, fn)
    local items = loader()
    local i = (items[idx] and items[idx].text == text_at_click) and idx or nil
    if not i then
      for j, it in ipairs(items) do if it.text == text_at_click then i = j; break end end
    end
    if i then fn(items, i); saver(items) end
  end

  -- State ------------------------------------------------------------------
  local S = {
    view = 'list',   -- 'list' | 'archive'
    sel = nil,       -- { idx, text } of the selected row
    confirm = false, -- delete armed on the selected row
    scroll = 0,
    pending = nil,   -- { kind = 'add' | 'edit', idx, text } while zenity is open
    last = nil,      -- { idx, t } of the last row click, for double-click
    hits = {},       -- clickable rects from the last draw
    rect = nil,      -- card rect in drawing coordinates
    base = nil,      -- update_interval to restore after FAST
    fast_until = 0,
  }

  local function fast(seconds)
    if not S.base then
      S.base = conky_info and conky_info.update_interval or 2
      conky_set_update_interval(FAST)
    end
    S.fast_until = math.max(S.fast_until, os.time() + (seconds or 2))
  end

  local function settle()
    if S.base and not S.pending and os.time() >= S.fast_until then
      conky_set_update_interval(S.base)
      S.base = nil
    end
  end

  local function select_row(idx, t)
    if S.sel and S.sel.idx == idx then S.sel = nil else S.sel = { idx = idx, text = t } end
    S.confirm = false
  end

  local PROMPT = 't=$(zenity --entry --title="$1" --text="$2" --entry-text="$3" '
    .. '--ok-label="$4" --width=460 2>/dev/null); s=$?; '
    .. 'printf "%s\\n%s" "$s" "$t" > "$5.tmp" && mv -f "$5.tmp" "$5"'

  local function prompt(kind, title, label, initial, ok, idx)
    if S.pending then return end
    os.remove(REPLY)
    S.pending = { kind = kind, idx = idx, text = initial }
    os.execute('sh -c ' .. q(PROMPT) .. ' sh ' .. q(title) .. ' ' .. q(label) .. ' '
      .. q(initial) .. ' ' .. q(ok) .. ' ' .. q(REPLY) .. ' >/dev/null 2>&1 &')
    fast()
  end

  local function take_reply()
    if not S.pending then return end
    local f = io.open(REPLY)
    if not f then return end
    local status = f:read('*l')
    local t = (f:read('*a') or ''):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    f:close()
    os.remove(REPLY)
    local p = S.pending
    S.pending = nil
    fast(1)
    if status ~= '0' or t == '' then return end
    if p.kind == 'add' then
      local items = load_list()
      items[#items + 1] = { done = false, text = t }
      save_list(items)
      S.view = 'list'
      S.scroll = math.max(0, #items - ROWS)
    else
      mutate(load_list, save_list, p.idx, p.text, function(items, i) items[i].text = t end)
      if S.sel and S.sel.idx == p.idx then S.sel.text = t end
    end
  end

  -- Drawing ----------------------------------------------------------------
  -- row = { idx, text } marks a whole-row rect, which right-click selects.
  local function hit(x, y, w, h, fn, row) S.hits[#S.hits + 1] = { x, y, w, h, fn, row } end

  local function button(cr, cx, cy, glyph, active, fn)
    rrect(cr, cx - 12, cy - 12, 24, 24, 7)
    if active then cairo_set_source_rgba(cr, hex(C.gold, 0.22)) else rgba(cr, C.track) end
    cairo_fill(cr)
    icon(cr, glyph, cx, cy, 14, active and { hex(C.gold) } or C.fg)
    hit(cx - 13, cy - 13, 26, 26, fn)
  end

  local function checkbox(cr, bx, by, done, faded)
    rrect(cr, bx, by, 15, 15, 4.5)
    if done then
      cairo_set_source_rgba(cr, hex(C.gold, faded and 0.45 or 1)); cairo_fill(cr)
      icon(cr, G.check, bx + 7.5, by + 7.5, 11, { hex('0e1328') })
    else
      cairo_set_line_width(cr, 1.6)
      cairo_set_source_rgba(cr, C.lilac[1], C.lilac[2], C.lilac[3], faded and 0.35 or 0.7)
      cairo_stroke(cr)
    end
  end

  -- Right-aligned row actions; returns the x where they start.
  local function actions(cr, right, cy, list)
    local x = right
    for k = #list, 1, -1 do
      local a = list[k]
      if a.label then
        local tw = ui.measure(cr, a.label, 11, { bold = true })
        local bw = tw + 16
        x = x - bw
        rrect(cr, x, cy - 10, bw, 20, 6); cairo_set_source_rgba(cr, C.pink[1], C.pink[2], C.pink[3], 0.2)
        cairo_fill(cr)
        text(cr, a.label, x + 8, cy + 4, 11, C.pink, { bold = true })
        hit(x, cy - 12, bw, 24, a.fn)
      else
        x = x - 22
        icon(cr, a.glyph, x + 11, cy, 13.5, a.colour or C.fg)
        hit(x, cy - 12, 22, 24, a.fn)
      end
      x = x - 2
    end
    return x
  end

  local function delete_action(fn)
    if S.confirm then return { label = 'Delete', fn = fn } end
    return { glyph = G.delete, colour = C.pink, fn = function() S.confirm = true end }
  end

  local function draw(cr, x, y, w, h)
    take_reply()
    settle()
    S.rect, S.hits = { x, y, w, h }, {}
    card(cr, x, y, w, h)
    local p = 20
    local archive = S.view == 'archive'
    local items = archive and load_archive() or load_list()
    local gold = { hex(C.gold) }

    icon(cr, archive and G.archive or G.list, x + p + 7, y + 30, 15, gold)
    text(cr, archive and 'ARCHIVE' or 'CHECKLIST', x + p + 22, y + 35, 12, gold, { bold = true })

    -- header buttons, right to left
    local done = 0
    for _, it in ipairs(items) do if it.done then done = done + 1 end end
    local bx, by = x + w - p - 12, y + 30
    local function reset() S.sel, S.confirm, S.scroll = nil, false, 0 end
    if archive then
      button(cr, bx, by, G.back, false, function() S.view = 'list'; reset() end)
      bx = bx - 30
    else
      button(cr, bx, by, G.add, S.pending and S.pending.kind == 'add',
        function() prompt('add', 'Checklist', 'New item', '', 'Add') end)
      bx = bx - 30
      button(cr, bx, by, G.archive, false, function() S.view = 'archive'; reset() end)
      bx = bx - 30
      if done > 0 then
        button(cr, bx, by, G.sweep, false, function()
          local keep, gone = {}, {}
          for _, it in ipairs(load_list()) do table.insert(it.done and gone or keep, it) end
          append_archive(gone); save_list(keep); reset()
        end)
        bx = bx - 30
      end
    end
    local count = archive and (#items .. (#items == 1 and ' item' or ' items'))
      or (#items > 0 and (done .. ' / ' .. #items) or '')
    text(cr, count, bx - 6, y + 35, 12, C.dim, { bold = true, align = 'r' })

    local top = y + 56
    if not archive and #items > 0 then
      rrect(cr, x + p, y + 46, w - 2 * p, 3, 1.5); rgba(cr, C.track); cairo_fill(cr)
      if done > 0 then
        rrect(cr, x + p, y + 46, math.max(3, (w - 2 * p) * done / #items), 3, 1.5)
        cairo_set_source_rgba(cr, hex(C.gold)); cairo_fill(cr)
      end
    end

    -- clicks in the list area that miss a row clear the selection
    hit(x, top - 4, w, ROWS * RH + 8, function() S.sel, S.confirm = nil, false end)

    if #items == 0 then
      local cy = top + ROWS * RH / 2
      text(cr, archive and 'Archive is empty' or 'Nothing on the list', x + w / 2, cy - 4, 13,
        C.fg, { bold = true, align = 'c' })
      text(cr, archive and 'Archived items show up here' or 'Click + to add one', x + w / 2, cy + 16,
        11.5, C.dim, { bold = true, align = 'c' })
      return
    end

    S.scroll = math.max(0, math.min(S.scroll, #items - ROWS))
    if S.sel and not (items[S.sel.idx] and items[S.sel.idx].text == S.sel.text) then
      S.sel, S.confirm = nil, false
    end
    local loader = archive and load_archive or load_list
    local saver = archive and save_archive or save_list
    local right = x + w - p + (#items > ROWS and -6 or 0)

    for k = 1, math.min(ROWS, #items - S.scroll) do
      local i = S.scroll + k
      local it = items[i]
      local ry = top + (k - 1) * RH
      local cy = ry + RH / 2 - 1
      local selected = S.sel and S.sel.idx == i
      local function on(fn) return function() mutate(loader, saver, i, it.text, fn) end end

      if selected then
        rrect(cr, x + p - 8, ry, right - x - p + 14, RH - 2, 7); rgba(cr, C.track); cairo_fill(cr)
      end
      hit(x + p - 8, ry, right - x - p + 14, RH - 2, function(ev)
        local again = S.last and S.last.idx == i and ev.time - S.last.t < DOUBLE_MS
        S.last = { idx = i, t = ev.time }
        if again and not archive then
          S.sel = { idx = i, text = it.text }
          prompt('edit', 'Checklist', 'Edit item', it.text, 'Save', i)
        else
          select_row(i, it.text)
        end
      end, { i, it.text })

      checkbox(cr, x + p, cy - 7.5, it.done, archive)
      if not archive then
        hit(x + p - 8, ry, 30, RH - 2, on(function(list, j) list[j].done = not list[j].done end))
      end

      local tx, limit = x + p + 26, right - 4
      if selected then
        local list
        if archive then
          list = {
            { glyph = G.restore, colour = C.green, fn = function()
              mutate(load_archive, save_archive, i, it.text, function(a, j)
                local back = load_list()
                back[#back + 1] = { done = a[j].done, text = a[j].text }
                save_list(back)
                table.remove(a, j)
              end)
              S.sel = nil
            end },
            delete_action(function() on(function(a, j) table.remove(a, j) end)(); S.sel = nil end),
          }
        else
          list = {
            { glyph = G.up, fn = on(function(l, j)
              if j > 1 then l[j], l[j - 1] = l[j - 1], l[j]; S.sel.idx = j - 1 end
              S.scroll = math.min(S.scroll, S.sel.idx - 1)
            end) },
            { glyph = G.down, fn = on(function(l, j)
              if j < #l then l[j], l[j + 1] = l[j + 1], l[j]; S.sel.idx = j + 1 end
              S.scroll = math.max(S.scroll, S.sel.idx - ROWS)
            end) },
            { glyph = G.edit, fn = function() prompt('edit', 'Checklist', 'Edit item', it.text, 'Save', i) end },
            { glyph = G.stow, fn = function()
              on(function(l, j) append_archive({ l[j] }); table.remove(l, j) end)()
              S.sel = nil
            end },
            delete_action(function() on(function(l, j) table.remove(l, j) end)(); S.sel = nil end),
          }
        end
        limit = actions(cr, right, cy, list) - 8
      elseif archive then
        local m = tonumber(it.date:sub(6, 7))
        local stamp = ui.MONTHS[m] .. ' ' .. tonumber(it.date:sub(9, 10))
        limit = right - text(cr, stamp, right, cy + 4, 11, C.dim, { bold = true, align = 'r' }) - 10
      end

      local o = { bold = true }
      local s = fit(cr, it.text, 12.5, limit - tx, o)
      local c = it.done and C.dim or C.fg
      local adv = text(cr, s, tx, cy + 4.5, 12.5, c, o)
      if it.done then
        cairo_set_line_width(cr, 1.2); rgba(cr, C.dim)
        cairo_move_to(cr, tx, cy); cairo_line_to(cr, tx + adv, cy); cairo_stroke(cr)
      end
    end

    if #items > ROWS then
      local tx, th = x + w - p + 2, ROWS * RH - 6
      rrect(cr, tx, top + 2, 3, th, 1.5); rgba(cr, C.track); cairo_fill(cr)
      local tl = math.max(14, th * ROWS / #items)
      local ty = top + 2 + (th - tl) * S.scroll / (#items - ROWS)
      rrect(cr, tx, ty, 3, tl, 1.5); rgba(cr, C.lilac); cairo_fill(cr)
    end
  end

  -- Mouse --------------------------------------------------------------------
  -- ev.x/ev.y are window coordinates; dx is the drawing offset (cairo_translate).
  local function mouse(ev, dx)
    local r = S.rect
    if not r then return false end
    local mx, my = ev.x - dx, ev.y
    if mx < r[1] or mx > r[1] + r[3] or my < r[2] or my > r[2] + r[4] then return false end
    if ev.type == 'mouse_scroll' then
      if ev.direction == 'up' then S.scroll = S.scroll - 1
      elseif ev.direction == 'down' then S.scroll = S.scroll + 1 end
      S.scroll = math.max(0, S.scroll)
      fast()
      return true
    end
    if ev.type ~= 'button_down' then return ev.type == 'button_up' end
    local hits = S.hits
    S.hits = {}   -- ignore further clicks until the next draw has fresh rects
    for k = #hits, 1, -1 do
      local h = hits[k]
      if mx >= h[1] and mx <= h[1] + h[3] and my >= h[2] and my <= h[2] + h[4] then
        if ev.button == 'left' then
          h[5](ev)
          break
        elseif ev.button == 'right' and h[6] then
          select_row(h[6][1], h[6][2])
          break
        end
      end
    end
    fast()
    return true
  end

  return { draw = draw, mouse = mouse }
end
