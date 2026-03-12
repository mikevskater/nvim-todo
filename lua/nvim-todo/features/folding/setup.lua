-- Fold configuration for markdown collapsible headers.
local M = {}

local config = require('nvim-todo.config')
local expr = require('nvim-todo.features.folding.expr')

---Configure folding on the notepad window.
---Uses foldmethod=manual with custom toggle/close-all/open-all actions.
---@param winid number
---@param bufnr number
function M.setup(winid, bufnr)
  if not config.get('collapsible_headers') then
    return
  end

  expr.set_state(winid, bufnr)

  local win_opts = {
    foldenable = true,
    foldmethod = 'manual',
    foldtext = "v:lua.require'nvim-todo.features.folding.expr'.fold_text()",
    foldlevel = 99,
  }

  for opt, val in pairs(win_opts) do
    vim.api.nvim_set_option_value(opt, val, { win = winid })
  end
end

return M
