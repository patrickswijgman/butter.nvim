local config = require("butter.config")
local core = require("butter.core")

local M = {}

---Register the plugin's autocommands.
function M.setup()
  local group = vim.api.nvim_create_augroup("Butter", { clear = true })

  if config.opts.auto_open then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = function()
        core.open_butter(vim.fn.argv()[1])
      end,
      desc = "Open Butter when Neovim is opened with a directory",
      group = group,
    })
  end
end

return M
