-- Hide/show/toggle commands for completed tasks.
local M = {}

local filter = require('nvim-todo.features.hide_completed.filter')

---Hide completed tasks in the buffer.
---@param bufnr number
function M.hide(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local state = filter.get_state()
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  state.original_lines = lines

  local visible, ranges, line_map = filter.compute_ranges(lines)
  state.hidden_ranges = ranges
  state.line_map = line_map

  if #ranges == 0 then
    vim.notify("No completed tasks to hide", vim.log.levels.INFO)
    state.original_lines = nil
    state.line_map = nil
    return
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, visible)
  state.active = true

  local hidden_count = 0
  for _, range in ipairs(ranges) do
    hidden_count = hidden_count + #range.lines
  end
  vim.notify("Hidden " .. hidden_count .. " completed line(s)", vim.log.levels.INFO)
end

---Show (restore) completed tasks in the buffer.
---@param bufnr number
function M.show(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local full = filter.get_full_lines(bufnr)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, full)

  local state = filter.get_state()
  state.active = false
  state.hidden_ranges = {}
  state.original_lines = nil
  state.line_map = nil

  vim.notify("Showing all tasks", vim.log.levels.INFO)
end

---Toggle hide/show completed tasks.
---@param bufnr number
function M.toggle(bufnr)
  if filter.is_active() then
    M.show(bufnr)
  else
    M.hide(bufnr)
  end
end

return M
