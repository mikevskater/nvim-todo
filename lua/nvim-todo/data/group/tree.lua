---Tree traversal and lookup for the group hierarchy.
---@class nvim-todo.data.group.tree
local M = {}

local state = require('nvim-todo.data.group.state')
local path_utils = require('nvim-todo.data.group.path')

---Find a group by dot-separated path. Walks the tree by segments.
---@param path string? Dot-separated path (e.g. "Work.Projects")
---@return GroupEntry? group, GroupEntry[]? parent_list, number? index_in_parent
function M.find_group(path)
  if not path or path == "" then return nil, nil, nil end

  local parts = path_utils.split_path(path)
  if #parts == 0 then return nil, nil, nil end

  local current_list = state.groups
  local group = nil
  local parent_list = nil
  local index = nil

  for _, segment in ipairs(parts) do
    local found = false
    for i, g in ipairs(current_list) do
      if g.name == segment then
        group = g
        parent_list = current_list
        index = i
        current_list = g.children or {}
        found = true
        break
      end
    end
    if not found then
      return nil, nil, nil
    end
  end

  return group, parent_list, index
end

---Build a flat list of visible tree nodes for rendering.
---Only recurses into groups whose paths are in expanded_set.
---@param expanded_set table<string, boolean> Set of expanded paths
---@return TreeNode[]
function M.build_tree(expanded_set)
  local nodes = {}

  local function walk(list, parent_path, level)
    for _, g in ipairs(list) do
      local gpath = path_utils.join_path(parent_path, g.name)
      local has_children = g.children ~= nil and #g.children > 0
      local is_expanded = has_children and (expanded_set[gpath] == true)

      table.insert(nodes, {
        path = gpath,
        name = g.name,
        level = level,
        is_expanded = is_expanded,
        has_children = has_children,
        group = g,
      })

      if is_expanded then
        walk(g.children, gpath, level + 1)
      end
    end
  end

  walk(state.groups, "", 0)
  return nodes
end

return M
