local config = require("butter.config")
local core = require("butter.core")

local M = {}

local function open()
  local arg = vim.fn.argv()[1]
  if arg and vim.fn.isdirectory(arg) == 1 then
    core.open_butter(arg)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup("Butter", { clear = true })

  if config.opts.auto_open then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = open,
      desc = "Open Butter when Neovim is opened with a directory",
      group = group,
    })
  end
end

return M
