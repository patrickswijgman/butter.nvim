local M = {}

---Run a system command synchronously.
---
---@param command string[] command and args
---@param stdin? string|string[] optional input for the command
---
---@return string # command output or empty string on error
function M.cmd(command, stdin)
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
function M.split_lines(str)
  return vim.split(str, "\n", { trimempty = true })
end

---Sort given lines directory-first.
---
---@param a string
---@param b string
---@return boolean
function M.sort(a, b)
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
function M.get_current_file()
  return vim.fn.fnamemodify(vim.fn.expand("%"), ":.")
end

---Parent directory of `path`.
---
---@param path string
---
---@return string
function M.get_parent_dir(path)
  return vim.fn.fnamemodify(path, ":h")
end

---Whether `path` is a directory, i.e. `fd` printed it with a trailing slash.
---
---@param path string
---
---@return boolean
function M.is_directory(path)
  return vim.endswith(path, "/")
end

---Create the directory that must exist before mv/cp `src` to `dst`.
---A file going into `b/` needs `b` created; a dir renamed to `b/` must NOT
---have `b` pre-created, or mv would nest it as `b/<src>` instead of renaming.
---
---@param src string source file or directory
---@param dst string destination file or directory
function M.ensure_dir(src, dst)
  local dir

  if M.is_directory(dst) and not M.is_directory(src) then
    dir = dst:gsub("/+$", "")
  else
    dir = M.get_parent_dir(dst:gsub("/+$", ""))
  end

  M.cmd({ "mkdir", "-p", dir })
end

---Resolve the icon and highlight group for a path. Requires nvim-web-devicons;
---returns nil when it isn't installed, so no icon is shown.
---
---@param path string
---
---@return string? icon
---@return string? hl highlight group
function M.get_icon(path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return nil
  end

  if M.is_directory(path) then
    return "󰉋", "Directory"
  end

  local name = vim.fn.fnamemodify(path, ":t")
  local ext = vim.fn.fnamemodify(path, ":e")
  return devicons.get_icon(name, ext, { default = true })
end

return M
