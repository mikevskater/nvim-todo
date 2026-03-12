-- Re-exports for all feature modules.
local M = {}

M.folding = require('nvim-todo.features.folding')
M.hide_completed = require('nvim-todo.features.hide_completed')
M.sticky_headers = require('nvim-todo.features.sticky_headers')

return M
