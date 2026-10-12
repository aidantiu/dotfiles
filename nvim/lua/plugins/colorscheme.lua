-- Nightswim: Tokyo Night re-tinted with the palette in ~/dotfiles/nightswim/palette.sh.
-- Transparent background so Alacritty's opacity and the wallpaper show through
-- (Alacritty only makes the *default* background translucent).
local ns = {
  bg = "#0e1328", -- deep pool water
  surface = "#2a2f55", -- pool shadow
  edge = "#3b4170",
  fg = "#d6cfe8", -- lavender deck
  mist = "#a59fc0",
  dim = "#6b6f9a",
  lilac = "#9a8cc8",
  gold = "#e8a95b",
  soft_gold = "#d9b98a",
  pink = "#d79bc9",
  red = "#c9566b",
  red_bright = "#e07a8c",
  green = "#86b3a0",
  teal = "#5f9bb0",
  cyan = "#8cc4d4",
  blue = "#8497d6",
}

return {
  {
    "folke/tokyonight.nvim",
    opts = {
      style = "night",
      transparent = true,
      styles = {
        sidebars = "transparent",
        floats = "transparent",
        comments = { italic = true },
        keywords = { italic = false },
      },
      on_colors = function(c)
        c.bg = ns.bg
        c.bg_dark = "#0b0f20"
        c.bg_dark1 = "#090c1a"
        c.bg_float = ns.bg
        c.bg_sidebar = ns.bg
        c.bg_popup = "#121833"
        c.bg_highlight = "#1c2244"
        c.bg_visual = ns.surface
        c.bg_search = ns.edge
        c.border = ns.surface
        c.border_highlight = ns.lilac
        c.fg = ns.fg
        c.fg_dark = ns.mist
        c.fg_float = ns.fg
        c.fg_sidebar = ns.mist
        c.fg_gutter = ns.edge
        c.comment = ns.dim
        c.dark3 = ns.dim
        c.dark5 = ns.mist
        c.terminal_black = ns.edge
        c.blue = ns.blue
        c.blue0 = ns.surface
        c.blue1 = ns.cyan
        c.blue2 = ns.cyan
        c.blue5 = ns.cyan
        c.blue6 = ns.cyan
        c.blue7 = ns.surface
        c.cyan = ns.cyan
        c.teal = ns.teal
        c.purple = ns.lilac
        c.magenta = ns.lilac
        c.magenta2 = ns.pink
        c.orange = ns.gold
        c.yellow = ns.soft_gold
        c.green = ns.green
        c.green1 = ns.cyan
        c.green2 = ns.teal
        c.red = ns.red_bright
        c.red1 = ns.red
        c.error = ns.red
        c.warning = ns.gold
        c.info = ns.blue
        c.hint = ns.teal
        c.git = { add = ns.green, change = ns.blue, delete = ns.red, ignore = ns.dim }
      end,
      on_highlights = function(hl, c)
        hl.CursorLineNr = { fg = ns.gold, bold = true }
        hl.LineNr = { fg = ns.edge }
        hl.WinSeparator = { fg = ns.surface }
        hl.Visual = { bg = ns.surface }
        hl.FloatBorder = { fg = ns.surface }
        hl.FloatTitle = { fg = ns.lilac, bold = true }
        hl.Pmenu = { bg = "#121833", fg = ns.fg }
        hl.PmenuSel = { bg = ns.surface, fg = ns.fg, bold = true }
      end,
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}
