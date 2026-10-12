-- Nightswim: nvim matched to the terminal.
--   ansi:   alacritty/alacritty.toml [colors.*] (also nvim's :terminal colors)
--   syntax: bat/themes/Nightswim.tmTheme (what bat and delta highlight with)
-- Tokyo Night provides the plugin/UI highlight groups, re-tinted to these colors.
-- Transparent background so Alacritty's opacity and the wallpaper show through.
local ansi = {
  "#0e1328", "#c9566b", "#5f8a7a", "#e8a95b", "#5a6fb8", "#b07ab8", "#5f9bb0", "#bdb3d6", -- normal 0-7
  "#3b4170", "#e07a8c", "#86b3a0", "#f4c57f", "#8497d6", "#d79bc9", "#8cc4d4", "#e6e0f2", -- bright 8-15
}
local ns = {
  bg = "#0e1328", -- colors.primary.background
  fg = "#d6cfe8", -- colors.primary.foreground
  selection = "#2a2f55", -- colors.selection.background
  cursor = "#e8a95b", -- colors.cursor.cursor
  edge = ansi[9], -- bright black
  white = ansi[8],
  -- bat Nightswim.tmTheme scopes
  comment = "#6b6f9a",
  string = "#86b3a0",
  constant = "#e8a95b",
  keyword = "#9a8cc8",
  func = "#8497d6",
  type = "#d79bc9",
  member = "#8cc4d4",
  invalid = "#c9566b",
}

local function syntax(hl)
  local set = function(groups, spec)
    for _, g in ipairs(groups) do
      hl[g] = spec
    end
  end
  set({ "Comment", "@comment", "@lsp.type.comment" }, { fg = ns.comment, italic = true })
  set({ "String", "Character", "@string", "@character", "@markup.raw", "@markup.raw.block" }, { fg = ns.string })
  set({ "Constant", "Number", "Float", "Boolean", "@constant", "@constant.builtin", "@number", "@number.float", "@boolean", "@lsp.type.enumMember" }, { fg = ns.constant })
  set({ "Keyword", "Statement", "Conditional", "Repeat", "Exception", "StorageClass", "Include", "PreProc", "@keyword", "@keyword.function", "@keyword.return", "@keyword.operator", "@keyword.import", "@keyword.conditional", "@keyword.repeat", "@keyword.exception", "@keyword.modifier", "@keyword.type", "@lsp.type.keyword" }, { fg = ns.keyword })
  set({ "Function", "@function", "@function.call", "@function.method", "@function.method.call", "@function.builtin", "@lsp.type.function", "@lsp.type.method" }, { fg = ns.func })
  set({ "Type", "Structure", "Typedef", "@type", "@type.builtin", "@type.definition", "@constructor", "@module", "@lsp.type.type", "@lsp.type.class", "@lsp.type.interface", "@lsp.type.enum", "@lsp.type.struct", "@lsp.type.namespace" }, { fg = ns.type })
  set({ "@variable.parameter", "@variable.member", "@property", "@attribute", "@tag.attribute", "@lsp.type.parameter", "@lsp.type.property" }, { fg = ns.member })
  set({ "Tag", "@tag", "@tag.builtin" }, { fg = ns.type })
  set({ "Identifier", "@variable", "@lsp.type.variable", "Operator", "@operator", "Delimiter", "@punctuation", "@punctuation.bracket", "@punctuation.delimiter" }, { fg = ns.fg })
  set({ "Error", "@error" }, { fg = ns.invalid })
  for i = 1, 6 do
    hl["@markup.heading." .. i .. ".markdown"] = { fg = ns.constant, bold = true }
  end
  set({ "@markup.heading", "Title" }, { fg = ns.constant, bold = true })
  set({ "Added", "DiffAdded", "@diff.plus" }, { fg = ns.string })
  set({ "Removed", "DiffRemoved", "@diff.minus" }, { fg = ns.invalid })
  set({ "Changed", "DiffChanged", "@diff.delta" }, { fg = ns.constant })
end

return {
  {
    "folke/tokyonight.nvim",
    init = function()
      -- :terminal buffers use exactly Alacritty's 16 colours.
      vim.api.nvim_create_autocmd("ColorScheme", {
        pattern = "tokyonight*",
        callback = function()
          for i, c in ipairs(ansi) do
            vim.g["terminal_color_" .. (i - 1)] = c
          end
        end,
      })
    end,
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
        c.bg_dark = ns.bg
        c.bg_dark1 = ns.bg
        c.bg_float = ns.bg
        c.bg_sidebar = ns.bg
        c.bg_popup = ns.bg
        c.bg_highlight = "#1c2244"
        c.bg_visual = ns.selection
        c.bg_search = ns.edge
        c.border = ns.selection
        c.border_highlight = ns.keyword
        c.fg = ns.fg
        c.fg_dark = ns.white
        c.fg_float = ns.fg
        c.fg_sidebar = ns.white
        c.fg_gutter = ns.edge
        c.comment = ns.comment
        c.dark3 = ns.comment
        c.dark5 = ns.white
        c.terminal_black = ns.edge
        c.blue = ansi[13]
        c.blue0 = ns.selection
        c.blue1 = ansi[15]
        c.blue2 = ansi[15]
        c.blue5 = ansi[15]
        c.blue6 = ansi[15]
        c.blue7 = ns.selection
        c.cyan = ansi[15]
        c.teal = ansi[7]
        c.purple = ns.keyword
        c.magenta = ns.keyword
        c.magenta2 = ansi[14]
        c.orange = ansi[4]
        c.yellow = ansi[12]
        c.green = ansi[11]
        c.green1 = ansi[15]
        c.green2 = ansi[7]
        c.red = ansi[10]
        c.red1 = ansi[2]
        c.error = ansi[2]
        c.warning = ansi[4]
        c.info = ansi[13]
        c.hint = ansi[7]
        c.git = { add = ns.string, change = ns.constant, delete = ns.invalid, ignore = ns.comment }
      end,
      on_highlights = function(hl, c)
        syntax(hl)
        hl.Cursor = { fg = ns.bg, bg = ns.cursor }
        hl.CursorLineNr = { fg = ns.cursor, bold = true }
        hl.LineNr = { fg = ns.edge }
        hl.WinSeparator = { fg = ns.selection }
        hl.Visual = { bg = ns.selection }
        hl.FloatBorder = { fg = ns.selection }
        hl.FloatTitle = { fg = ns.keyword, bold = true }
        hl.Pmenu = { bg = ns.bg, fg = ns.fg }
        hl.PmenuSel = { bg = ns.selection, fg = ns.fg, bold = true }
      end,
    },
  },
  { "LazyVim/LazyVim", opts = { colorscheme = "tokyonight" } },
}
