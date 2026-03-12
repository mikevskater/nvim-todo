---Load and normalize group data from Pantry format.
---@class nvim-todo.data.manager.loader
local M = {}

local state = require('nvim-todo.data.group.state')
local tree = require('nvim-todo.data.group.tree')
local codec = require('nvim-todo.storage.pantry.codec')

---Detect format and normalize to version 2 (groups format).
---@param raw_data table? Raw parsed JSON from Pantry
---@return table normalized Always in version 2 format (content still Base64-encoded)
function M.normalize(raw_data)
  if not raw_data then
    return {
      version = 2,
      groups = { { name = "Default", content = "", cursor_pos = { line = 1, col = 0 } } },
      active_group = "Default",
      last_modified = os.time(),
    }
  end

  if raw_data.version == 2 then
    raw_data.expanded_paths = raw_data.expanded_paths or {}
    return raw_data
  end

  return {
    version = 2,
    groups = {
      {
        name = "Default",
        content = raw_data.content or "",
        cursor_pos = raw_data.cursor_pos or { line = 1, col = 0 },
      },
    },
    active_group = "Default",
    last_modified = raw_data.last_modified or os.time(),
  }
end

---Recursively decode a group entry from Pantry format.
---@param raw table Raw group with Base64-encoded content
---@return GroupEntry
local function decode_group(raw)
  local decoded = codec.decode_content(raw.content)
  local entry = {
    name = raw.name,
    content = decoded,
    cursor_pos = raw.cursor_pos or { line = 1, col = 0 },
    icon = raw.icon,
    icon_color = raw.icon_color,
    name_color = raw.name_color,
    line_numbers = raw.line_numbers or nil,
    children = nil,
    saved_content = decoded,
    dirty = false,
  }
  if raw.children and #raw.children > 0 then
    entry.children = {}
    for _, child in ipairs(raw.children) do
      table.insert(entry.children, decode_group(child))
    end
  end
  return entry
end

---Load groups from normalized data. Decodes Base64 content recursively.
---@param data table? Raw data from Pantry (or nil for empty)
function M.load(data)
  local normalized = M.normalize(data)

  state.groups = {}
  for _, g in ipairs(normalized.groups) do
    table.insert(state.groups, decode_group(g))
  end

  state.active_group = normalized.active_group
  if not tree.find_group(state.active_group) then
    state.active_group = state.groups[1] and state.groups[1].name or nil
  end

  state.expanded_paths = normalized.expanded_paths or {}
  state.loaded = true
  state.dirty = false
end

---Check if groups are loaded.
---@return boolean
function M.is_loaded()
  return state.loaded
end

---Get total number of groups (recursive). Delegates to crud.
---@return number
function M.get_group_count()
  local crud = require('nvim-todo.data.group.crud')
  return crud.get_group_count()
end

---Reset all state (discard unsaved changes).
function M.reset()
  state.reset()
end

return M
