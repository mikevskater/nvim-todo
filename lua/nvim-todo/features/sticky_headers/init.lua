-- Re-exports for sticky_headers feature.
local M = {}

local setup_mod = require('nvim-todo.features.sticky_headers.setup')
local render = require('nvim-todo.features.sticky_headers.render')

M.setup = setup_mod.setup
M.cleanup = setup_mod.cleanup
M.update = render.update
M.close_overlay = render.close_overlay

return M
