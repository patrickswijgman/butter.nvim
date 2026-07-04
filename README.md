# butter.nvim

A minimal, buttery-smooth file explorer for Neovim. Inspired by [oil.nvim](https://github.com/stevearc/oil.nvim).

![Butter neovim plugin preview image](preview.png)

# Features

- File operations (create, ename, move, copy, delete)
- Open as the default file explorer when invoked e.g. as `nvim .`

## Requirements

- Neovim 0.10+
- [fd](https://github.com/sharkdp/fd)
- Unix commands: `mkdir`, `touch`, `mv`, `cp`, `rm`
- [nvim-web-devicons](https://github.com/nvim-tree/nvim-web-devicons) (optional)

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "patrickswijgman/butter.nvim",
  config = function()
    require("butter").setup()
  end,
}
```

With `vim.pack`:

```lua
vim.pack.add({
  "https://github.com/patrickswijgman/butter.nvim",
})

require("butter").setup()
```

## Usage

Run `:Butter` to open the explorer in the current window, with the cursor on the
file you were editing. Inside the buffer:

| Key               | Action                                                     |
| ----------------- | ---------------------------------------------------------- |
| `o` / `enter`     | Open the file or directory under the cursor                |
| `-` / `backspace` | Go up to the parent directory                              |
| `a`               | Add a file or directory (trailing `/` creates a directory) |
| `m`               | Move / rename                                              |
| `c`               | Copy                                                       |
| `d`               | Delete (with confirmation)                                 |

Navigating into or out of a directory changes the window's working directory
(via `:lcd`), so it stays in sync with what you're browsing.

Add it as a keymap in your config:

```lua
vim.keymap.set("n", "<leader>e", "<cmd>Butter<cr>", { desc = "Open file explorer" })
```

## Configuration

`setup()` takes an optional table. These are the defaults:

```lua
require("butter").setup({
  show_hidden = false, -- show hidden files, e.g. `.env`
  no_ignore = false,   -- also show files ignored by .gitignore etc.
  exclude = {},        -- paths to exclude, e.g. { ".git", "node_modules", "dist" }
  sort = true,         -- directory-first sorting; set to false to keep the original order
  auto_open = false,   -- open Butter when Neovim starts with a directory, e.g. `nvim .`
})
```

Note that if you set `auto_open` to `true`, be sure to disable `netrw` (Neovim's builtin file explorer) to prevent race conditions.
Add this to your config:

```lua
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
```
