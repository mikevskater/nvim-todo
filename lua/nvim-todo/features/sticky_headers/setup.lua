-- Autocmd wiring and cleanup for sticky headers.
local M = {}

local config = require('nvim-todo.config')
local render = require('nvim-todo.features.sticky_headers.render')

---@type number?
local augroup = nil

---Set up sticky headers for the notepad window.
---@param winid number
---@param bufnr number
function M.setup(winid, bufnr)
  if not config.get('sticky_headers') then
    return
  end

  render.set_state(winid, bufnr)

  augroup = vim.api.nvim_create_augroup('NvimTodoStickyHeaders', { clear = true })

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'WinScrolled' }, {
    group = augroup,
    buffer = bufnr,
    callback = function()
      vim.schedule(render.update)
    end,
  })

  vim.api.nvim_create_autocmd('VimResized', {
    group = augroup,
    callback = function()
      local state = render.get_state()
      if state.notepad_win and vim.api.nvim_win_is_valid(state.notepad_win) then
        vim.schedule(render.update)
      end
    end,
  })
end

---Clean up overlay and autocmds.
function M.cleanup()
  render.close_overlay()
  if augroup then
    pcall(vim.api.nvim_del_augroup_by_id, augroup)
  end
  augroup = nil
  local state = render.get_state()
  state.notepad_win = nil
  state.notepad_buf = nil
  state._adjusting = false
  state._overlay_height = 0
end

return M
