---@class Opts
---@field show_hidden? boolean
---@field no_ignore? boolean
---@field exclude? string[]
---@field sort? boolean
---@field auto_open? boolean

local M = {}

---@type Opts
local defaults = {
  show_hidden = false,
  no_ignore = false,
  exclude = {},
  sort = true,
  auto_open = false,
}

---@type Opts
M.opts = defaults

---@param user_opts? Opts
function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", {}, defaults, user_opts or {})
end

return M
