-- Re-exports for hide_completed feature.
local M = {}

local filter = require('nvim-todo.features.hide_completed.filter')
local toggle_mod = require('nvim-todo.features.hide_completed.toggle')

M.toggle = toggle_mod.toggle
M.hide = toggle_mod.hide
M.show = toggle_mod.show
M.is_active = filter.is_active
M.get_full_lines = filter.get_full_lines
M.get_full_content = filter.get_full_content
M.get_original_lnum = filter.get_original_lnum
M.reset = filter.reset

return M
