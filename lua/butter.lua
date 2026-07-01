---@class IconsOpts
---@field dir string icon for a directory
---@field file string icon for a file

---@class Opts
---@field show_hidden? boolean show hidden files
---@field no_ignore? boolean don't use ignore files such as .gitignore
---@field exclude? string[] exclude a file or directory
---@field sort? fun(a: string, b: string): boolean custom sort, directory-first by default
---@field auto_open? boolean auto open when neovim is invoked with a directory e.g. `nvim .`
---@field icons? IconsOpts options for icons

local M = {}

local opts ---@type Opts
local buf
local ns = vim.api.nvim_create_namespace("butter")

---@type Opts
local default_opts = {
  show_hidden = false,
  no_ignore = false,
  exclude = {},
  sort = nil,
  auto_open = false,
  icons = {
    dir = "",
    file = "",
  },
}

---Run a system command synchronously.
---
---@param command string[] command and args
---@param stdin? string|string[] optional input for the command
---
---@return string # command output or empty string on error
local function cmd(command, stdin)
  local result = vim.system(command, { text = true, stdin = stdin }):wait()

  if result.code ~= 0 then
    vim.notify(("Command failed with error:\n%s"):format(result.stderr), vim.log.levels.ERROR)
    return ""
  end

  return result.stdout
end

---Split string on new lines.
---
---@param str string input string
---
---@return string[]
local function split_lines(str)
  return vim.split(str, "\n", { trimempty = true })
end

---Sort given lines directory-first.
---
---@param a string
---@param b string
---@return boolean
local function sort(a, b)
  local a_path = a:lower()
  local b_path = b:lower()
  local a_dir = a_path:match("^(.*)/") or ""
  local b_dir = b_path:match("^(.*)/") or ""
  if a_dir ~= b_dir then
    return a_dir < b_dir
  end
  return a_path < b_path
end

---Path of the current buffer's file, relative to the working directory.
---
---@return string
local function get_current_file()
  return vim.fn.fnamemodify(vim.fn.expand("%"), ":.")
end

---Parent directory of `path`.
---
---@param path string
---
---@return string
local function get_parent_dir(path)
  return vim.fn.fnamemodify(path, ":h")
end

---Whether `path` is a directory, i.e. `fd` printed it with a trailing slash.
---
---@param path string
---
---@return boolean
local function is_directory(path)
  return vim.endswith(path, "/")
end

---Create the directory that must exist before mv/cp `src` to `dst`.
---A file going into `b/` needs `b` created; a dir renamed to `b/` must NOT
---have `b` pre-created, or mv would nest it as `b/<src>` instead of renaming.
---
---@param src string source file or directory
---@param dst string destination file or directory
local function ensure_dir(src, dst)
  local dir
  if is_directory(dst) and not is_directory(src) then
    dir = dst:gsub("/+$", "")
  else
    dir = get_parent_dir(dst:gsub("/+$", ""))
  end
  cmd({ "mkdir", "-p", dir })
end

---Construct the `fd` command with arguments and execute
---it to retrieve a sorted list of files and or directories.
local function get_files()
  local command = { "fd" }

  if opts.show_hidden then
    table.insert(command, "--hidden")
  end

  if opts.no_ignore then
    table.insert(command, "--no-ignore")
  end

  for _, exclude in ipairs(opts.exclude) do
    table.insert(command, "--exclude")
    table.insert(command, exclude)
  end

  local output = cmd(command)
  local files = split_lines(output)

  if opts.sort then
    table.sort(files, opts.sort)
  else
    table.sort(files, sort)
  end

  return files
end

---Move the cursor to the line matching `path`, if present.
---
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

---Create the scratch buffer and show it in the current window.
local function create_buf_in_current_win()
  buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.api.nvim_set_current_buf(buf)
end

---Refresh the buffer with the current file list and its icons/highlights.
local function update_buf()
  local files = get_files()

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, files)
  vim.bo[buf].modifiable = false

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

  for i, path in ipairs(files) do
    local is_dir = is_directory(path)
    local icon = is_dir and opts.icons.dir or opts.icons.file
    local hl = is_dir and "Directory" or "Normal"

    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
      virt_text = { { icon, hl } },
      virt_text_pos = "inline",
    })

    local slash = path:match("^.*()/")
    if slash then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {
        end_col = slash,
        hl_group = "Directory",
      })
    end
  end
end

---Edit the file under the cursor. Directories are ignored.
local function open()
  local path = vim.api.nvim_get_current_line()
  if path ~= "" and not is_directory(path) then
    vim.cmd.edit(path)
  end
end

---Prompt for a path and create it. A trailing slash makes a directory,
---otherwise a file (with any missing parent directories).
local function add()
  local path = vim.api.nvim_get_current_line()

  local dir
  if is_directory(path) then
    dir = path
  else
    local parent_dir = get_parent_dir(path)
    dir = parent_dir == "." and "" or ("%s/"):format(parent_dir)
  end

  local input = vim.fn.input({ prompt = "Add: ", default = dir, completion = "file" })
  if input ~= "" then
    if is_directory(input) then
      cmd({ "mkdir", "-p", input })
    else
      cmd({ "mkdir", "-p", get_parent_dir(input) })
      cmd({ "touch", input })
    end

    update_buf()
    jump_to(input)
  end
end

---Move/rename the file under the cursor to a prompted destination.
local function move()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Move: ", default = src, completion = "file" })
  if dst ~= "" then
    ensure_dir(src, dst)
    cmd({ "mv", "-n", src, dst })
    update_buf()
    jump_to(dst)
  end
end

---Copy the file/directory under the cursor to a prompted destination.
local function copy()
  local src = vim.api.nvim_get_current_line()
  local dst = vim.fn.input({ prompt = "Copy: ", default = src, completion = "file" })
  if dst ~= "" then
    ensure_dir(src, dst)
    cmd({ "cp", "-rn", src, dst })
    update_buf()
    jump_to(dst)
  end
end

---Delete the file/directory under the cursor after a confirmation prompt.
local function delete()
  local path = vim.api.nvim_get_current_line()
  local result = vim.fn.confirm(("Delete: %s ?"):format(path), "&Yes\n&No", 2)
  if result == 1 then
    cmd({ "rm", "-rf", path })
    update_buf()
  end
end

---Wipe the Butter buffer, returning to the previously edited file.
local function close()
  vim.api.nvim_buf_delete(buf, { force = true })
end

---Set the buffer-local keymaps for the file operations.
local function set_buf_keymaps()
  local keymap_opts = { buffer = buf, nowait = true }
  vim.keymap.set("n", "<cr>", open, keymap_opts)
  vim.keymap.set("n", "a", add, keymap_opts)
  vim.keymap.set("n", "m", move, keymap_opts)
  vim.keymap.set("n", "c", copy, keymap_opts)
  vim.keymap.set("n", "d", delete, keymap_opts)
  vim.keymap.set("n", "q", close, keymap_opts)
  vim.keymap.set("n", "<esc>", close, keymap_opts)
end

---Open Butter in the current window, cursor on the current file.
local function open_butter()
  local file = get_current_file()
  create_buf_in_current_win()
  set_buf_keymaps()
  update_buf()
  jump_to(file)
end

---Open Butter on startup when Neovim was launched with a directory argument.
local function auto_open_butter()
  local arg = vim.fn.argv()[1]
  if arg ~= "" and vim.fn.isdirectory(arg) == 1 then
    vim.cmd.cd(arg)
    open_butter()
  end
end

---Initialize plugin.
---
---@param user_opts? Opts user options
function M.setup(user_opts)
  opts = vim.tbl_deep_extend("force", {}, default_opts, user_opts or {}) ---@type Opts

  vim.api.nvim_create_user_command("Butter", open_butter, { desc = "Open Butter" })

  local group = vim.api.nvim_create_augroup("Butter", { clear = true })

  if opts.auto_open then
    vim.api.nvim_create_autocmd("VimEnter", {
      callback = auto_open_butter,
      desc = "Open Butter when Neovim is opened with a directory",
      group = group,
    })
  end
end

return M
