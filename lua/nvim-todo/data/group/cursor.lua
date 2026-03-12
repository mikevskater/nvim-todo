---Cursor position accessors for the active group.
---@class nvim-todo.data.group.cursor
local M = {}

local state = require('nvim-todo.data.group.state')
local tree = require('nvim-todo.data.group.tree')

---Get the active group's cursor position.
---@return { line: number, col: number }
function M.get_active_cursor()
  local g = tree.find_group(state.active_group)
  if g then
    return g.cursor_pos or { line = 1, col = 0 }
  end
  return { line = 1, col = 0 }
end

---Set the active group's cursor position.
---@param pos { line: number, col: number }
function M.set_active_cursor(pos)
  local g = tree.find_group(state.active_group)
  if g then
    g.cursor_pos = pos
  end
end

return M
