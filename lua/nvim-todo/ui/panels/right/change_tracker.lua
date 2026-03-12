-- Unsaved state tracking for the right panel buffer.
local M = {}

local state = require('nvim-todo.ui.multi_panel.state')
local right_buffer = require('nvim-todo.ui.panels.right.buffer')
local active = require('nvim-todo.data.manager.active')
local path_utils = require('nvim-todo.data.group.path')

---Update unsaved state by comparing current buffer content to saved snapshot.
function M.update_unsaved_state()
  if not state.right_buf or not vim.api.nvim_buf_is_valid(state.right_buf) then
    return
  end

  local current = right_buffer.get_content()
  local prev = state.has_unsaved_changes

  if state.saved_content then
    state.has_unsaved_changes = (current ~= state.saved_content)
  else
    state.has_unsaved_changes = (#current > 0)
  end

  -- Update right panel title and left panel marker if state changed
  if prev ~= state.has_unsaved_changes and state.panel_state then
    local group_name = active.get_active_group() or "Editor"
    local parts = path_utils.split_path(group_name)
    local display_name = parts[#parts] or group_name
    local title = state.has_unsaved_changes
      and (state.unsaved_marker .. " " .. display_name .. " ")
      or (" " .. display_name .. " ")
    state.panel_state:update_panel_title(state.PANEL_EDITOR, title)

    -- Re-render left panel so the active group's unsaved marker updates
    state.panel_state:render_panel(state.PANEL_GROUPS)
  end
end

---Attach change tracking to the given buffer via nvim_buf_attach.
---@param buf number
function M.attach(buf)
  vim.api.nvim_buf_attach(buf, false, {
    on_lines = function()
      if state.ignore_changes then
        return
      end
      vim.schedule(function()
        M.update_unsaved_state()
        right_buffer.sync_scrollbar()
      end)
    end,
  })
end

return M
