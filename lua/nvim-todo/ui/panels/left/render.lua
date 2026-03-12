-- Left panel render callback for nvim-float's on_render.
local M = {}

local state = require('nvim-todo.ui.multi_panel.state')
local tree = require('nvim-todo.data.group.tree')
local active = require('nvim-todo.data.manager.active')
local highlights = require('nvim-todo.ui.highlights')
local icons = require('nvim-todo.ui.icons')

---Render the left panel group tree.
---@param _mp_state table MultiPanelState (unused)
---@return string[] lines, table[] highlights
function M.render(_mp_state)
  local nodes = tree.build_tree(state.tree_state.expanded)
  state.tree_state.visible_nodes = nodes

  local lines = {}
  local hls = {}
  local active_path = active.get_active_group()

  for i, node in ipairs(nodes) do
    local indent = string.rep("  ", node.level)
    local icon = icons.get_group_icon(node.group, node.is_expanded, node.has_children)
    local line = indent .. icon .. " " .. node.name

    -- Check if this group has unsaved changes
    local is_active = (node.path == active_path)
    local is_dirty = is_active and state.has_unsaved_changes or (not is_active and node.group.dirty == true)

    if is_dirty then
      line = line .. " " .. state.unsaved_marker
    end

    table.insert(lines, line)

    local line_idx = i - 1  -- 0-indexed for nvim API

    if is_active then
      table.insert(hls, {
        line = line_idx,
        col_start = 0,
        col_end = #line,
        hl_group = 'NvimTodoActiveGroup',
      })
    else
      local icon_start = #indent
      local icon_end = icon_start + #icon
      local name_start = icon_end + 1
      local name_end = name_start + #node.name

      if node.group.icon_color and node.group.icon_color ~= "" then
        table.insert(hls, {
          line = line_idx,
          col_start = icon_start,
          col_end = icon_end,
          hl_group = highlights.get_color_hl(node.group.icon_color),
        })
      end

      if node.group.name_color and node.group.name_color ~= "" then
        table.insert(hls, {
          line = line_idx,
          col_start = name_start,
          col_end = name_end,
          hl_group = highlights.get_color_hl(node.group.name_color),
        })
      end

      if is_dirty then
        local marker_start = name_end + 1
        table.insert(hls, {
          line = line_idx,
          col_start = marker_start,
          col_end = #line,
          hl_group = 'NvimTodoUnsaved',
        })
      end
    end
  end

  if #lines == 0 then
    lines = { "  (no groups)" }
  end

  return lines, hls
end

return M
