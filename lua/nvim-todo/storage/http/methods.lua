---@class nvim-todo.storage.http.methods
local M = {}

local request = require('nvim-todo.storage.http.request')

---Make an async GET request.
---@param url string Request URL
---@param headers table<string, string>? HTTP headers
---@param callback fun(response: HttpResponse?, err: string?)
function M.get(url, headers, callback)
  request.request('GET', url, nil, headers, callback)
end

---Make an async POST request.
---@param url string Request URL
---@param data any Request body
---@param headers table<string, string>? HTTP headers
---@param callback fun(response: HttpResponse?, err: string?)
function M.post(url, data, headers, callback)
  request.request('POST', url, data, headers, callback)
end

---Make an async PUT request.
---@param url string Request URL
---@param data any Request body
---@param headers table<string, string>? HTTP headers
---@param callback fun(response: HttpResponse?, err: string?)
function M.put(url, data, headers, callback)
  request.request('PUT', url, data, headers, callback)
end

---Make an async DELETE request.
---@param url string Request URL
---@param headers table<string, string>? HTTP headers
---@param callback fun(response: HttpResponse?, err: string?)
function M.delete(url, headers, callback)
  request.request('DELETE', url, nil, headers, callback)
end

---URL-encode a string (RFC 3986).
---@param str string? Input string
---@return string encoded URL-encoded string
function M.url_encode(str)
  if not str then return "" end
  str = string.gsub(str, "\n", "\r\n")
  str = string.gsub(str, "([^%w%-%.%_%~ ])", function(c)
    return string.format("%%%02X", string.byte(c))
  end)
  str = string.gsub(str, " ", "+")
  return str
end

---Build URL query string from a table of key-value pairs.
---@param params table<string, any>? Parameters
---@return string query_string Empty string or "?key=val&..." format
function M.build_query_string(params)
  if not params or vim.tbl_isempty(params) then
    return ""
  end
  local parts = {}
  for key, value in pairs(params) do
    table.insert(parts, M.url_encode(key) .. '=' .. M.url_encode(tostring(value)))
  end
  return '?' .. table.concat(parts, '&')
end

return M
