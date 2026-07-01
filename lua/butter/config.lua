---@class Opts
---@field show_hidden? boolean show hidden files
---@field no_ignore? boolean don't use ignore files such as .gitignore
---@field exclude? string[] exclude a file or directory
---@field sort? fun(a: string, b: string): boolean|false custom sort, or `false` to keep fd's order; directory-first by default
---@field auto_open? boolean auto open when neovim is invoked with a directory e.g. `nvim .`

local M = {}

---@type Opts
local defaults = {
  show_hidden = false,
  no_ignore = false,
  exclude = {},
  sort = nil,
  auto_open = false,
}

---Resolved options, populated by `setup()`.
---@type Opts
M.opts = defaults

---Merge user options over the defaults.
---
---@param user_opts? Opts
function M.setup(user_opts)
  M.opts = vim.tbl_deep_extend("force", {}, defaults, user_opts or {})
end

return M
