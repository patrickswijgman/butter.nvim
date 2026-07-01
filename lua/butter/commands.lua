local core = require("butter.core")

local M = {}

---Register the plugin's user commands.
function M.setup()
  vim.api.nvim_create_user_command("Butter", function()
    core.open_butter()
  end, {
    desc = "Open Butter",
  })
end

return M
