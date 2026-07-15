local config = require("butter.config")
local utils = require("butter.utils")

local M = {}

local buf
local ns = vim.api.nvim_create_namespace("butter")

---@return string[]
function M.get_files()
  local command = { "fd" }

  if config.opts.show_hidden then
    table.insert(command, "--hidden")
  end

  if config.opts.no_ignore then
    table.insert(command, "--no-ignore")
  end

  for _, exclude in ipairs(config.opts.exclude) do
    table.insert(command, "--exclude")
    table.insert(command, exclude)
  end

  local output = utils.cmd(command)
  local files = utils.split_lines(output)

  if config.opts.sort then
    utils.sort(files)
  end

  return files
end

---@param path string
function M.jump_to(path)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if line == path then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
end

function M.create_buf_in_current_win()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.api.nvim_set_current_buf(buf)
end

function M.update_buf()
  local files = M.get_files()
  table.insert(files, 1, "../")
  table.insert(files, 1, "./")

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for i, path in ipairs(files) do
    local icon, hl = utils.get_icon(path)
    if icon then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        virt_text = { { icon .. " ", hl } },
        virt_text_pos = "inline",
      })
    end

    local slash = path:match("^.*()/")
    if slash then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_col = slash,
        hl_group = "Directory",
      })
    end
  end
end

function M.open()
  local path = vim.api.nvim_get_current_line()
  if path == "" then
    return
  end

  if utils.is_directory(path) then
    M.open_butter(path)
  else
    vim.cmd.edit(path)
  end
end

function M.add()
  local path = vim.api.nvim_get_current_line()

  local dir
  if utils.is_directory(path) then
    dir = path
  else
    local parent_dir = utils.get_parent_dir(path)
    dir = parent_dir == "." and "" or ("%s/"):format(parent_dir)
  end

  local input = vim.fn.input({ prompt = "Add: ", default = dir, completion = "file" })
  if input == "" then
    return
  end

  if utils.is_directory(input) then
    utils.cmd({ "mkdir", "-p", input })
  else
    utils.cmd({ "mkdir", "-p", utils.get_parent_dir(input) })
    utils.cmd({ "touch", input })
  end

  M.update_buf()
  M.jump_to(input)
end

function M.move()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Move: ", default = src, completion = "file" })

  if dst == "" then
    return
  end

  utils.ensure_dir(src, dst)
  utils.cmd({ "mv", "-n", src, dst })
  M.update_buf()
  M.jump_to(dst)
end

function M.copy()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Copy: ", default = src, completion = "file" })

  if dst == "" then
    return
  end

  utils.ensure_dir(src, dst)
  utils.cmd({ "cp", "-rn", src, dst })
  M.update_buf()
  M.jump_to(dst)
end

function M.delete()
  local path = vim.api.nvim_get_current_line()
  local result = vim.fn.confirm(("Delete: %s ?"):format(path), "&Yes\n&No", 2)

  if result ~= 1 then
    return
  end

  utils.cmd({ "rm", "-rf", path })
  M.update_buf()
end

function M.up()
  M.open_butter("../")
end

function M.set_buf_keymaps()
  local opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "<cr>", M.open, opts)
  vim.keymap.set("n", "<bs>", M.up, opts)
  vim.keymap.set("n", "-", M.up, opts)
  vim.keymap.set("n", "o", M.open, opts)
  vim.keymap.set("n", "a", M.add, opts)
  vim.keymap.set("n", "m", M.move, opts)
  vim.keymap.set("n", "c", M.copy, opts)
  vim.keymap.set("n", "d", M.delete, opts)
end

---@param path? string
function M.open_butter(path)
  if path then
    vim.cmd.lcd(path)
  end

  local file = utils.get_current_file()
  M.create_buf_in_current_win()
  M.set_buf_keymaps()
  M.update_buf()
  M.jump_to(file)
end

return M
