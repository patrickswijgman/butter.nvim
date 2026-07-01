-- Headless test runner for Butter's file operations.
--
-- Run from the repo root:
-- `nvim --headless --noplugin -u NONE --cmd "set rtp+=$PWD" -l tests/run.lua`

local butter = require("butter")
butter.setup()
local ops = butter._test

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

print(("\n%d failed"):format(failures))
vim.cmd(failures == 0 and "qa!" or "cq!")
