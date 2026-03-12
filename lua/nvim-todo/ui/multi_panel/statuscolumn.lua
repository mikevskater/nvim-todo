-- Statuscolumn rendering for original line numbers when hide_completed is active.
local M = {}

local state = require('nvim-todo.ui.multi_panel.state')
local hide_completed = require('sheet_todo.features.hide_completed')

---Setup global statuscolumn function.
---Sets `_G.NvimTodoStatusCol` for use in statuscolumn option.
function M.setup_global()
  _G.NvimTodoStatusCol = function()
    local lnum = vim.v.lnum
    local virtnum = vim.v.virtnum

    -- virtnum > 0 means this is a wrapped continuation line — show blank
    if virtnum > 0 then
      return "    "
    end

    local orig = hide_completed.get_original_lnum(lnum)

    -- Check if relative line numbers are enabled on the current window
    local relnum = vim.wo.relativenumber
    if relnum then
      local cursor_lnum = vim.api.nvim_win_get_cursor(0)[1]
      local dist = math.abs(lnum - cursor_lnum)
      if dist == 0 then
        return string.format("%3d ", orig)
      else
        return string.format("%3d ", dist)
      end
    end

    return string.format("%3d ", orig)
  end
end

---Apply or clear statuscolumn on the right panel window.
---Sets statuscolumn when BOTH line numbers are on AND hide_completed is active.
function M.apply()
  if not state.right_win or not vim.api.nvim_win_is_valid(state.right_win) then
    return
  end
  local line_nums_on = vim.api.nvim_get_option_value('number', { win = state.right_win })
  if line_nums_on and hide_completed.is_active() then
    vim.api.nvim_set_option_value('statuscolumn', '%!v:lua.NvimTodoStatusCol()', { win = state.right_win })
  else
    vim.api.nvim_set_option_value('statuscolumn', '', { win = state.right_win })
  end
end

return M
