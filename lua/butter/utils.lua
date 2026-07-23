local M = {}

---@param command string[]
---@param stdin? string|string[]
---@return string
function M.cmd(command, stdin)
  local result = vim.system(command, { text = true, stdin = stdin }):wait()

  if result.code ~= 0 then
    vim.notify(("Command failed with error:\n%s"):format(result.stderr), vim.log.levels.ERROR)
    return ""
  end

  return result.stdout
end

---@param str string
---@return string[]
function M.split_lines(str)
  return vim.split(str, "\n", { trimempty = true })
end

---@return string
function M.get_current_file()
  return vim.fn.fnamemodify(vim.fn.expand("%"), ":.")
end

---@param path string
---@return string?
function M.get_parent_dir(path)
  local dir = vim.fn.fnamemodify(vim.fs.normalize(path), ":h")
  if dir == "." then
    return nil
  end
  return dir .. "/"
end

---@param path string
---@return boolean
function M.is_directory(path)
  return vim.endswith(path, "/")
end

---A file going into `b/` needs `b` created; a dir renamed to `b/` must NOT
---have `b` pre-created, or mv would nest it as `b/<src>` instead of renaming.
---@param src string
---@param dst string
function M.ensure_dir(src, dst)
  local dir
  if M.is_directory(dst) and not M.is_directory(src) then
    dir = dst
  else
    dir = M.get_parent_dir(dst)
  end

  if dir then
    M.cmd({ "mkdir", "-p", "--", dir })
  end
end

---Requires nvim-web-devicons; returns nil when it isn't installed, so no icon is shown.
---@param path string
---@return string? icon
---@return string? hl
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
