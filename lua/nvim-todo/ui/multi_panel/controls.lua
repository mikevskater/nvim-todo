-- Controls bar and completion disable for the multi-panel UI.
local M = {}

local config = require('nvim-todo.config')
local str_utils = require('nvim-todo.utils.string')

---Build controls array for nvim-float's "? = Controls" footer.
---@return table[]
function M.build_controls()
  local km = config.get('keymaps')
  return {
    { header = "Groups", keys = {
      { key = "Enter", desc = "Select group" },
      { key = "zo", desc = "Expand group" },
      { key = "zc", desc = "Collapse / go to parent" },
      { key = "a", desc = "Add child group" },
      { key = "A", desc = "Add root group" },
      { key = "d", desc = "Delete group" },
      { key = "r", desc = "Rename group" },
      { key = "i", desc = "Set icon" },
      { key = "c", desc = "Set color" },
      { key = "J / K", desc = "Reorder group" },
      { key = "m", desc = "Move to different parent" },
    }},
    { header = "Editing", keys = {
      { key = str_utils.fmt_key(km.save), desc = "Save to cloud" },
      { key = str_utils.fmt_key(km.revert), desc = "Revert to saved" },
    }},
    { header = "View", keys = {
      { key = str_utils.fmt_key(km.toggle_completed), desc = "Hide/show completed" },
      { key = str_utils.fmt_key(km.next_todo), desc = "Jump to next todo" },
      { key = str_utils.fmt_key(km.toggle_checkbox), desc = "Toggle [ ]/[x] checkbox" },
      { key = str_utils.fmt_key(km.toggle_line_numbers), desc = "Toggle line numbers" },
    }},
    { header = "Folding", keys = {
      { key = "za", desc = "Toggle fold" },
      { key = "zM", desc = "Close all folds" },
      { key = "zR", desc = "Open all folds" },
    }},
    { header = "Navigation", keys = {
      { key = "Tab / S-Tab", desc = "Switch panel" },
      { key = str_utils.fmt_key(km.close), desc = "Close" },
      { key = "?", desc = "Show controls" },
    }},
  }
end

---Disable autocomplete on the given buffer.
---@param buf number
function M.disable_completion(buf)
  if not config.get('disable_completion') then
    return
  end
  vim.b[buf].nvim_todo_buffer = true
  vim.b[buf].completion = false -- blink.cmp
  pcall(function()
    require('cmp').setup.buffer({ enabled = false }) -- nvim-cmp
  end)
end

return M
