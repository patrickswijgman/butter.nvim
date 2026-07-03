-- Run from the repo root:
-- `nvim --headless --noplugin -u NONE --cmd "set rtp+=$PWD" -l tests/run.lua`

local core = require("butter.core")
local utils = require("butter.utils")

require("butter").setup()

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

-- Fresh temp dir per test, populated from `files` (a list of paths, parents
-- created as needed), navigated into, with Butter opened so its listing reflects
-- the files and the ops' trailing update_buf()/jump_to() have a buffer to work on.
local function tree(files)
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  for _, rel in ipairs(files or {}) do
    local path = vim.fs.joinpath(root, rel)
    vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
    vim.fn.writefile({}, path)
  end
  vim.fn.chdir(root)
  vim.cmd("Butter")
  return root
end

-- Stub the interactive functions the ops read: the path under the cursor, the input
-- prompt (move/copy/add destination) and the delete confirmation. rawset is
-- needed for vim.fn, whose real entries come from a metatable __index.
-- input_default captures the prompt's prefilled value for add function default-dir test.
local input_default
local function stub(line, input_return, confirm_return)
  input_default = nil
  rawset(vim.api, "nvim_get_current_line", function()
    return line
  end)
  rawset(vim.fn, "input", function(opts)
    input_default = opts.default
    return input_return
  end)
  rawset(vim.fn, "confirm", function()
    return confirm_return
  end)
end

local function cwd_tail()
  return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

local function buf_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

-- add ---------------------------------------------------------------------
tree()
stub("", "newfile.txt")
core.add()
check("add: creates a file", exists("newfile.txt") and not is_dir("newfile.txt"))

tree()
stub("", "newdir/")
core.add()
check("add: trailing slash creates a directory", is_dir("newdir"))

tree()
stub("", "a/b/c.txt")
core.add()
check("add: creates missing parent directories", exists("a/b/c.txt"))

tree({ "foo/x.txt" })
stub("foo/", "foo/new.txt")
core.add()
check("add: prefills the directory under the cursor", input_default == "foo/")

tree({ "root.txt" })
stub("root.txt", "root.txt")
core.add()
check("add: root-level file prefills no directory", input_default == "")

-- move --------------------------------------------------------------------
tree({ "old.txt" })
stub("old.txt", "new.txt")
core.move()
check("move: renames a file", exists("new.txt") and not exists("old.txt"))

tree({ "f.txt" })
stub("f.txt", "sub/")
core.move()
check("move: moves a file into a directory", exists("sub/f.txt") and not exists("f.txt"))

tree({ "a/f.txt" })
stub("a/f.txt", "b/g.txt")
core.move()
check("move: moves across directories", exists("b/g.txt") and not exists("a/f.txt"))

-- Renaming a directory must rename it, not nest it as new/old (the case
-- ensure_dir guards against by NOT pre-creating the destination).
tree({ "old/f.txt" })
stub("old/", "new/")
core.move()
check("move: renames a directory without nesting", exists("new/f.txt") and not exists("new/old"))

-- copy --------------------------------------------------------------------
tree({ "src.txt" })
stub("src.txt", "copy.txt")
core.copy()
check("copy: duplicates a file", exists("src.txt") and exists("copy.txt"))

tree({ "a/f.txt" })
stub("a/f.txt", "b/g.txt")
core.copy()
check("copy: copies across directories", exists("a/f.txt") and exists("b/g.txt"))

tree({ "src/f.txt" })
stub("src/", "dst/")
core.copy()
check("copy: copies a directory recursively", exists("dst/f.txt") and exists("src/f.txt"))

-- mv/cp run with -n; an existing destination must not be clobbered.
tree({ "a.txt", "b.txt" })
stub("a.txt", "b.txt")
core.move()
check("move: -n does not clobber an existing destination", exists("a.txt") and exists("b.txt"))

-- delete ------------------------------------------------------------------
tree({ "del.txt" })
stub("del.txt", nil, 1) -- 1 = "Yes"
core.delete()
check("delete: removes a confirmed file", not exists("del.txt"))

tree({ "keep.txt" })
stub("keep.txt", nil, 2) -- 2 = "No"
core.delete()
check("delete: keeps the file when cancelled", exists("keep.txt"))

-- navigation --------------------------------------------------------------
tree({ "sub/inner.txt" })
stub("sub/")
core.open()
check("open: entering a directory changes cwd into it", cwd_tail() == "sub")
check("open: listing shows the entered directory's contents", vim.tbl_contains(buf_lines(), "inner.txt"))

core.up()
check("up: returns to the parent directory", vim.tbl_contains(buf_lines(), "sub/"))

tree({ "file.txt" })
stub("file.txt")
core.open()
check("open: opening a file edits it", vim.fn.fnamemodify(vim.fn.expand("%"), ":t") == "file.txt")

-- Reopening with :Butter (no path arg) must NOT reset to root: it stays in the
-- current dir with the cursor on the file you came from.
tree({ "sub/inner.txt" })
stub("sub/")
core.open()
stub("inner.txt")
core.open()
core.open_butter()
check("Butter: reopens in the current dir, not root", cwd_tail() == "sub")
local lines = buf_lines()
local cur = vim.api.nvim_win_get_cursor(0)[1]
check("Butter: cursor lands on the file you came from", lines[cur] == "inner.txt")

-- sort --------------------------------------------------------------------
-- utils.sort orders like `tree --dirsfirst`: directories before files at each
-- level, each directory's contents grouped under it, root-level files last.
check(
  "sort: subdirectories before files at each level, root-level files last",
  vim.deep_equal(
    utils.sort({
      "foo.txt",
      "bar.txt",
      "b/foo.txt",
      "a/b/foo.txt",
      "a/foo.txt",
    }),
    {
      "a/b/foo.txt",
      "a/foo.txt",
      "b/foo.txt",
      "bar.txt",
      "foo.txt",
    }
  )
)

check(
  "sort: a directory's line heads its own group, subdirs before files",
  vim.deep_equal(
    utils.sort({
      "foo.txt",
      "a/",
      "b/",
      "a/b/",
      "a/foo.txt",
      "a/b/foo.txt",
      "b/foo.txt",
      "bar.txt",
    }),
    {
      "a/",
      "a/b/",
      "a/b/foo.txt",
      "a/foo.txt",
      "b/",
      "b/foo.txt",
      "bar.txt",
      "foo.txt",
    }
  )
)

print(("\n%d failed"):format(failures))
vim.cmd(failures == 0 and "qa!" or "cq!")
