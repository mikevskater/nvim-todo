---Shared singleton state for the group data layer.
---Lua's module cache ensures every `require()` returns the same table reference.
---@class nvim-todo.data.group.state
---@field groups GroupEntry[]
---@field active_group string? Dot-separated path
---@field expanded_paths string[] Persisted expanded paths
---@field loaded boolean
---@field dirty boolean True when in-memory state differs from Pantry
local state = {
  groups = {},
  active_group = nil,
  expanded_paths = {},
  loaded = false,
  dirty = false,
}

---Reset all state to initial values (useful for testing and discard).
function state.reset()
  state.groups = {}
  state.active_group = nil
  state.expanded_paths = {}
  state.loaded = false
  state.dirty = false
end

return state
