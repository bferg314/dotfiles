local wezterm = require 'wezterm'
local act = wezterm.action
local config = wezterm.config_builder()

-- Shell
config.default_prog = { 'pwsh.exe', '-NoLogo' }

-- Font. The Nerd Font variant supplies the glyphs the starship prompt and
-- vim-airline draw; windows/installs/base.ps1 installs it.
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Consolas',
}
config.font_size = 14.0

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

return config
