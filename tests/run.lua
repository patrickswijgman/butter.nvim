-- Headless test runner for Butter's file operations.
--
-- Run from the repo root:
-- `nvim --headless --noplugin -u NONE --cmd "set rtp+=$PWD" -l tests/run.lua`

require("butter").setup()
local ops = require("butter.core")

local failures = 0
local function check(name, ok)
  print((ok and "ok   - " or "FAIL - ") .. name)
  if not ok then
    failures = failures + 1
  end
end

local function exists(path)
  return vim.uv.fs_stat(path) ~= nil
end

local function is_dir(path)
  local s = vim.uv.fs_stat(path)
  return s ~= nil and s.type == "directory"
end

-- Fresh temp dir per test, navigated into, with a Butter buffer initialized so the
-- ops' trailing update_buf()/jump_to() have a valid buffer to work on.
local function fresh()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  vim.fn.chdir(dir)
  vim.cmd("Butter")
  return dir
end

-- Stub the interactive bits the ops read: the path under the cursor, the input
-- prompt (move/copy/add destination) and the delete confirmation. rawset is
-- needed for vim.fn, whose real entries come from a metatable __index.
local function stub(line, input_return, confirm_return)
  rawset(vim.api, "nvim_get_current_line", function()
    return line
  end)
  rawset(vim.fn, "input", function()
    return input_return
  end)
  rawset(vim.fn, "confirm", function()
    return confirm_return
  end)
end

-- add ---------------------------------------------------------------------
fresh()
stub("", "newfile.txt")
ops.add()
check("add: creates a file", exists("newfile.txt") and not is_dir("newfile.txt"))

fresh()
stub("", "newdir/")
ops.add()
check("add: trailing slash creates a directory", is_dir("newdir"))

fresh()
stub("", "a/b/c.txt")
ops.add()
check("add: creates missing parent directories", exists("a/b/c.txt"))

-- move --------------------------------------------------------------------
fresh()
vim.fn.writefile({}, "old.txt")
stub("old.txt", "new.txt")
ops.move()
check("move: renames a file", exists("new.txt") and not exists("old.txt"))

fresh()
vim.fn.writefile({}, "f.txt")
stub("f.txt", "sub/")
ops.move()
check("move: moves a file into a directory", exists("sub/f.txt") and not exists("f.txt"))

fresh()
vim.fn.mkdir("a", "p")
vim.fn.writefile({}, "a/f.txt")
stub("a/f.txt", "b/g.txt")
ops.move()
check("move: moves across directories", exists("b/g.txt") and not exists("a/f.txt"))

-- copy --------------------------------------------------------------------
fresh()
vim.fn.writefile({}, "src.txt")
stub("src.txt", "copy.txt")
ops.copy()
check("copy: duplicates a file", exists("src.txt") and exists("copy.txt"))

fresh()
vim.fn.mkdir("a", "p")
vim.fn.writefile({}, "a/f.txt")
stub("a/f.txt", "b/g.txt")
ops.copy()
check("copy: copies across directories", exists("a/f.txt") and exists("b/g.txt"))

-- delete ------------------------------------------------------------------
fresh()
vim.fn.writefile({}, "del.txt")
stub("del.txt", nil, 1) -- 1 = "Yes"
ops.delete()
check("delete: removes a confirmed file", not exists("del.txt"))

fresh()
vim.fn.writefile({}, "keep.txt")
stub("keep.txt", nil, 2) -- 2 = "No"
ops.delete()
check("delete: keeps the file when cancelled", exists("keep.txt"))

-- navigation --------------------------------------------------------------
-- Build a fresh tree, chdir into its root, open Butter. Returns the root path.
local function tree(spec)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  for _, rel in ipairs(spec) do
    if rel:sub(-1) == "/" then
      vim.fn.mkdir(root .. "/" .. rel, "p")
    else
      local parent = vim.fn.fnamemodify(rel, ":h")
      if parent ~= "." then
        vim.fn.mkdir(root .. "/" .. parent, "p")
      end
      vim.fn.writefile({}, root .. "/" .. rel)
    end
  end
  vim.fn.chdir(root)
  vim.cmd("Butter")
  return root
end

local function cwd_tail()
  return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

tree({ "sub/inner.txt" })
stub("sub/")
ops.open()
check("open: entering a directory changes cwd into it", cwd_tail() == "sub")
check("open: listing shows the entered directory's contents", vim.tbl_contains(buf_lines(), "inner.txt"))

ops.up()
check("up: returns to the parent directory", vim.tbl_contains(buf_lines(), "sub/"))

tree({ "file.txt" })
stub("file.txt")
ops.open()
check("open: opening a file edits it", vim.fn.fnamemodify(vim.fn.expand("%"), ":t") == "file.txt")

-- Reopening with :Butter (no path arg) must NOT reset to root: it stays in the
-- current dir with the cursor on the file you came from.
tree({ "sub/inner.txt" })
stub("sub/")
ops.open()
stub("inner.txt")
ops.open()
ops.open_butter()
check("Butter: reopens in the current dir, not root", cwd_tail() == "sub")
local lines = buf_lines()
local cur = vim.api.nvim_win_get_cursor(0)[1]
check("Butter: cursor lands on the file you came from", lines[cur] == "inner.txt")

print(("\n%d failed"):format(failures))
vim.cmd(failures == 0 and "qa!" or "cq!")
