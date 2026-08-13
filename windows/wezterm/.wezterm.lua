local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Shell
config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- Font. The Nerd Font variant supplies the glyphs the starship prompt and
-- vim-airline draw. Installed by the "Install Base Tools" option on every
-- platform. No fallback list: this is the one font, everywhere.
config.font = wezterm.font 'FiraCode Nerd Font Mono'
config.font_size = 15.0

-- Mouse behavior
config.mouse_bindings = {
  -- Release left button after a drag: copy selection to the clipboard.
  -- Using the "OrOpenLink" variant keeps plain clicks on URLs working.
  {
    event = { Up = { streak = 1, button = 'Left' } },
    mods = 'NONE',
    action = act.CompleteSelectionOrOpenLinkAtMouseCursor 'Clipboard',
  },
  -- Right click pastes
  {
    event = { Down = { streak = 1, button = 'Right' } },
    mods = 'NONE',
    action = act.PasteFrom 'Clipboard',
  },
}

config.canonicalize_pasted_newlines = "LineFeed"

config.hide_tab_bar_if_only_one_tab = true
config.window_decorations = "RESIZE"

-- Custom tab formatting example
wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
  local bg = tab.is_active and "#ae8b2d" or "#5c6d74"
  local fg = "#FFFFFF"
  local title = " " .. tab.tab_title .. " "
  return {
    { Background = { Color = bg } },
    { Foreground = { Color = fg } },
    { Text = title },
  }
end)
return config
