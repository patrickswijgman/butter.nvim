local autocmds = require("butter.autocmds")
local commands = require("butter.commands")
local config = require("butter.config")

local M = {}

---Initialize plugin.
---
---@param user_opts? Opts user options
function M.setup(user_opts)
  config.setup(user_opts)
  commands.setup()
  autocmds.setup()
end

return M
