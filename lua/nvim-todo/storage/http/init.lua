---@class nvim-todo.storage.http
local M = {}

local methods = require('nvim-todo.storage.http.methods')
local request = require('nvim-todo.storage.http.request')

M.get = methods.get
M.post = methods.post
M.put = methods.put
M.delete = methods.delete
M.url_encode = methods.url_encode
M.build_query_string = methods.build_query_string
M.request = request.request

return M
