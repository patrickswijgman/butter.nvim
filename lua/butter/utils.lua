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

---@class Path
---@field is_dir boolean
---@field segments string[]

---Split `path` into lowercased segments, remembering whether it's a directory.
---Computed once per entry so the comparison below stays cheap.
---
---@param path string
---
---@return Path
local function parse_path(path)
  return {
    is_dir = M.is_directory(path),
    segments = vim.split(path:lower(), "/", { plain = true, trimempty = true }),
  }
end

---Sort `files` in place: directories before files at each level, each
---directory's contents grouped under its own line, root-level files last
---(like `tree --dirsfirst`). Case-insensitive.
---
---@param files string[]
---
---@return string[]
function M.sort(files)
  ---@type Path[]
  local paths = {}
  for _, path in ipairs(files) do
    paths[path] = parse_path(path)
  end

  table.sort(files, function(a, b)
    a, b = paths[a], paths[b]

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

  return files
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
