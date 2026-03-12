-- Public API for multi-panel UI.
-- Re-exports show/close/cleanup/is_open + all sync wrappers.
local M = {}

local open = require('nvim-todo.ui.multi_panel.open')
local close_mod = require('nvim-todo.ui.multi_panel.close')
local sync = require('nvim-todo.ui.multi_panel.sync')

-- Lifecycle
M.show = open.show
M.close = close_mod.close
M.cleanup = close_mod.cleanup
M.is_open = close_mod.is_open

-- Sync wrappers (content, cursor, render)
M.set_content = sync.set_content
M.get_content = sync.get_content
M.get_cursor = sync.get_cursor
M.set_cursor = sync.set_cursor
M.mark_as_saved = sync.mark_as_saved
M.render_groups = sync.render_groups
M.update_editor_title = sync.update_editor_title
M.set_ignore_changes = sync.set_ignore_changes
M.sync_expanded_paths = sync.sync_expanded_paths
M.get_node_under_cursor = sync.get_node_under_cursor
M.get_group_under_cursor = sync.get_group_under_cursor

return M
