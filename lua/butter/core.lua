local config = require("butter.config")
local utils = require("butter.utils")

local M = {}

local buf
local ns = vim.api.nvim_create_namespace("butter")

---Sort the given list of files by directory first.
---@param files string[]
local function sort_files(files)
  local paths = {} ---@type Path[]
  for _, path in ipairs(files) do
    paths[path] = utils.parse_path(path)
  end

  table.sort(files, function(a, b)
    a = paths[a]
    b = paths[b]

    for i = 1, math.min(#a.segments, #b.segments) do
      if a.segments[i] ~= b.segments[i] then
        -- A segment is a directory if the path continues below it, or if it's
        -- the last segment of a directory entry (e.g. the "a/b/" line itself).
        -- Directories sort first.
        local a_dir = i < #a.segments or a.is_dir
        local b_dir = i < #b.segments or b.is_dir
        if a_dir ~= b_dir then
          return a_dir
        end

        return a.segments[i] < b.segments[i]
      end
    end

    -- One path is an ancestor of the other; the ancestor comes first.
    return #a.segments < #b.segments
  end)
end

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
    sort_files(files)
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
    dir = utils.get_parent_dir(path) or ""
  end

  local input = vim.fn.input({ prompt = "Add: ", default = dir, completion = "file" })
  if input == "" then
    return
  end

  utils.ensure_dir("", input)
  if not utils.is_directory(input) then
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
    vim.api.nvim_buf_set_name(buf, "[Butter]")

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

---@param entry? string
function M.open_butter(entry)
  local target = entry or utils.get_current_file()

  -- Support Neovim directory arg (e.g. `nvim lua/`) with and without trailing slash.
  if vim.fn.isdirectory(target) == 1 then
    target = vim.fs.normalize(target) .. "/"
  end

  -- Neovim opens a directory arg (e.g. `nvim lua/`) as a listed buffer
  -- that needs to be wiped afterwards to prevent it from lingering.
  local prev = vim.api.nvim_get_current_buf()
  local prev_is_dir = vim.fn.isdirectory(vim.api.nvim_buf_get_name(prev)) == 1

  setup_buf()
  update_buf()
  jump_to(target)

  if prev_is_dir and prev ~= buf then
    vim.api.nvim_buf_delete(prev, { force = true })
  end
end

return M
