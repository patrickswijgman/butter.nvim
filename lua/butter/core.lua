local config = require("butter.config")
local utils = require("butter.utils")

local M = {}

local buf
local ns = vim.api.nvim_create_namespace("butter")

---@return string[]
local function get_files()
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
local function jump_to(path)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  for i, line in ipairs(lines) do
    if line == path then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      return
    end
  end
end

local function update_buf()
  local files = get_files()

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

local function open()
  local path = vim.api.nvim_get_current_line()
  if path == "" or utils.is_directory(path) then
    return
  end

  vim.cmd.edit(path)
end

local function add()
  local path = vim.api.nvim_get_current_line()

  local dir
  if utils.is_directory(path) then
    dir = path
  else
    local parent_dir = utils.get_parent_dir(path)
    dir = parent_dir == "." and "" or parent_dir .. "/"
  end

  local input = vim.fn.input({ prompt = "Add: ", default = dir, completion = "file" })
  if input == "" then
    return
  end

  if utils.is_directory(input) then
    utils.cmd({ "mkdir", "-p", "--", input })
  else
    utils.cmd({ "mkdir", "-p", "--", utils.get_parent_dir(input) })
    utils.cmd({ "touch", "--", input })
  end

  update_buf()
  jump_to(input)
end

local function move()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Move: ", default = src, completion = "file" })

  if dst == "" then
    return
  end

  utils.ensure_dir(src, dst)
  utils.cmd({ "mv", "-n", "--", src, dst })
  update_buf()
  jump_to(dst)
end

local function copy()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Copy: ", default = src, completion = "file" })

  if dst == "" then
    return
  end

  utils.ensure_dir(src, dst)
  utils.cmd({ "cp", "-rn", "--", src, dst })
  update_buf()
  jump_to(dst)
end

local function delete()
  local path = vim.api.nvim_get_current_line()
  local result = vim.fn.confirm(("Delete: %s ?"):format(path), "&Yes\n&No", 2)

  if result ~= 1 then
    return
  end

  utils.cmd({ "rm", "-rf", "--", path })
  update_buf()
end

local function setup_buf()
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)

    local keymap_opts = { buffer = buf, nowait = true }
    vim.keymap.set("n", "<cr>", open, keymap_opts)
    vim.keymap.set("n", "o", open, keymap_opts)
    vim.keymap.set("n", "a", add, keymap_opts)
    vim.keymap.set("n", "m", move, keymap_opts)
    vim.keymap.set("n", "c", copy, keymap_opts)
    vim.keymap.set("n", "d", delete, keymap_opts)
  end

  vim.api.nvim_set_current_buf(buf)
end

---@param entry? string entry to place the cursor on; defaults to the current file
function M.open_butter(entry)
  entry = entry or utils.get_current_file()
  setup_buf()
  update_buf()
  jump_to(entry)
end

return M
