---Serialize and dirty-tracking for group data.
---@class nvim-todo.data.manager.saver
local M = {}

local state = require('nvim-todo.data.group.state')
local tree = require('nvim-todo.data.group.tree')
local codec = require('nvim-todo.storage.pantry.codec')

---Recursively encode a group entry for Pantry format.
---@param group GroupEntry
---@return table Raw group with Base64-encoded content
local function encode_group(group)
  local raw = {
    name = group.name,
    content = codec.encode_content(group.content),
    cursor_pos = group.cursor_pos,
  }
  if group.icon and group.icon ~= "" then
    raw.icon = group.icon
  end
  if group.icon_color and group.icon_color ~= "" then
    raw.icon_color = group.icon_color
  end
  if group.name_color and group.name_color ~= "" then
    raw.name_color = group.name_color
  end
  if group.line_numbers then
    raw.line_numbers = true
  end
  if group.children and #group.children > 0 then
    raw.children = {}
    for _, child in ipairs(group.children) do
      table.insert(raw.children, encode_group(child))
    end
  end
  return raw
end

---Serialize state to version 2 format ready for Pantry (Base64-encodes content recursively).
---@return table data Ready for JSON encoding and Pantry save
function M.serialize()
  local groups = {}
  for _, g in ipairs(state.groups) do
    table.insert(groups, encode_group(g))
  end

  local expanded = state.expanded_paths
  if expanded and #expanded == 0 then
    expanded = nil
  end

  return {
    version = 2,
    groups = groups,
    active_group = state.active_group,
    expanded_paths = expanded,
    last_modified = os.time(),
  }
end

---Recursively mark all groups as saved (snapshot content, clear dirty).
---@param list GroupEntry[]
local function mark_groups_saved(list)
  for _, g in ipairs(list) do
    g.saved_content = g.content
    g.dirty = false
    if g.children then
      mark_groups_saved(g.children)
    end
  end
end

---Mark in-memory state as matching Pantry (called after successful save).
function M.mark_as_saved()
  mark_groups_saved(state.groups)
  state.dirty = false
end

---Check if in-memory state has unsaved changes.
---@return boolean
function M.has_unsaved_changes()
  return state.dirty
end

---Check if a specific group has unsaved changes.
---@param path string Dot-separated path
---@return boolean
function M.is_group_dirty(path)
  local g = tree.find_group(path)
  if not g then return false end
  return g.dirty == true
end

return M
