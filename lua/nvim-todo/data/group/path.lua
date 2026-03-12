---Pure path utilities for dot-separated group paths.
---@class nvim-todo.data.group.path
local M = {}

---Split a dot-separated path into segments.
---@param path string?
---@return string[]
function M.split_path(path)
  if not path or path == "" then return {} end
  local parts = {}
  for part in path:gmatch("[^%.]+") do
    table.insert(parts, part)
  end
  return parts
end

---Join a parent path and a child name.
---@param parent_path string
---@param name string
---@return string
function M.join_path(parent_path, name)
  if not parent_path or parent_path == "" then
    return name
  end
  return parent_path .. "." .. name
end

---Get the parent path from a full path.
---@param path string
---@return string parent Empty string for root-level items
function M.get_parent_path(path)
  local parts = M.split_path(path)
  if #parts <= 1 then return "" end
  table.remove(parts)
  return table.concat(parts, ".")
end

return M
