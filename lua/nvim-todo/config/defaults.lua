---@class nvim-todo.config.defaults
---@field pantry_id string Pantry API ID (required, get from https://getpantry.cloud)
---@field basket_name string Name of the basket to store todos
---@field split_height_percent number Legacy split height percentage
---@field spinner_frames string[] Legacy spinner animation frames
---@field use_nvim_float boolean Use nvim-float if available
---@field keymaps table<string, string|string[]> Customizable key bindings
---@field disable_completion boolean Disable autocomplete in notepad buffer
---@field collapsible_headers boolean Collapsible markdown headers via manual folds
---@field sticky_headers boolean Show ancestor headers at top when scrolled past
---@field multi_panel boolean Enable left panel with group tree
---@field left_panel_width number Left panel width ratio (0-1)
---@field group_color_presets table[] Color presets for group customization
---@field pantry_basket_limit_bytes number Max basket size in bytes
---@field auto_refresh boolean Auto-refresh todos periodically
---@field refresh_interval_ms number Auto-refresh interval in milliseconds
---@field timeout_ms number HTTP request timeout in milliseconds

---@type nvim-todo.config.defaults
local defaults = {
  -- Pantry settings (REQUIRED)
  pantry_id = "",
  basket_name = "todos",

  -- UI settings
  split_height_percent = 25,
  spinner_frames = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },

  -- Float window provider
  use_nvim_float = true,

  -- Keymaps
  keymaps = {
    close = { '<Esc>', 'q' },
    save = '<C-s>',
    revert = '<A-r>',
    toggle_completed = '<leader>h',
    next_todo = 'n',
    toggle_line_numbers = '<leader>l',
    toggle_checkbox = '<C-t>',
  },

  -- Completion
  disable_completion = true,

  -- Folding
  collapsible_headers = true,

  -- Sticky headers
  sticky_headers = true,

  -- Multi-panel
  multi_panel = true,
  left_panel_width = 0.25,

  -- Group color presets
  group_color_presets = {
    { name = "Red", color = "#E06C75" },
    { name = "Green", color = "#98C379" },
    { name = "Blue", color = "#61AFEF" },
    { name = "Yellow", color = "#E5C07B" },
    { name = "Purple", color = "#C678DD" },
    { name = "Cyan", color = "#56B6C2" },
    { name = "Orange", color = "#D19A66" },
  },

  -- Storage limit
  pantry_basket_limit_bytes = 1509949,

  -- Behavior
  auto_refresh = false,
  refresh_interval_ms = 30000,
  timeout_ms = 10000,
}

return defaults
