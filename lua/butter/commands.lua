local core = require("butter.core")

local M = {}

---Open Butter.
local function open()
  core.open_butter()
end

---Register commands.
function M.setup()
  vim.api.nvim_create_user_command("Butter", open, { desc = "Open Butter" })
end

return M
