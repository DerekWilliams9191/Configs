-- nvim-treesitter on the rewritten `main` branch.
--
-- The `main` branch removed the old `nvim-treesitter.configs` module and its
-- `setup()` options table entirely. Parsers are now installed via
-- `require("nvim-treesitter").install(...)` (async), highlighting is enabled
-- per-buffer with `vim.treesitter.start()`, and indentation is opt-in via
-- `indentexpr`. Requires Neovim 0.11+.

-- Parsers to install. On `main` there is no `ensure_installed`; installation is
-- async and driven by `.install()` below.
local ensure_installed = {
  "json",
  "javascript",
  "typescript",
  "tsx",
  "yaml",
  "html",
  "css",
  "prisma",
  "markdown",
  "markdown_inline",
  "svelte",
  "graphql",
  "bash",
  "lua",
  "vim",
  "dockerfile",
  "gitignore",
  "query",
  "vimdoc",
  "c",
}

local max_filesize = 100 * 1024 -- 100 KB

--------------------------------------------------------------------------------
-- Minimal incremental selection.
--
-- The `incremental_selection` module was removed on the `main` branch, so we
-- reimplement the two mappings we actually used:
--   <C-s>  (normal) -> start selection at the node under the cursor
--   <C-s>  (visual) -> expand selection to the parent node
--   <bs>   (visual) -> shrink selection to the previous node
-- It keeps a stack of treesitter nodes and reselects their ranges.
--------------------------------------------------------------------------------
local incremental = { nodes = {} }

-- Treesitter ranges are 0-based with an exclusive end column. Translate the end
-- of a range to the (row, col) of the last character it actually covers.
local function last_char_pos(erow, ecol)
  if ecol > 0 then
    return erow, ecol - 1
  end
  local prev = math.max(erow - 1, 0)
  local line = vim.api.nvim_buf_get_lines(0, prev, prev + 1, false)[1] or ""
  return prev, math.max(#line - 1, 0)
end

local function visual_select(node)
  local srow, scol, erow, ecol = node:range()
  local lrow, lcol = last_char_pos(erow, ecol)
  -- Leave any current visual selection so `v` starts a fresh one.
  vim.cmd("normal! \27")
  vim.api.nvim_win_set_cursor(0, { srow + 1, scol })
  vim.cmd("normal! v")
  vim.api.nvim_win_set_cursor(0, { lrow + 1, lcol })
end

local function range_equal(a, b)
  local a1, a2, a3, a4 = a:range()
  local b1, b2, b3, b4 = b:range()
  return a1 == b1 and a2 == b2 and a3 == b3 and a4 == b4
end

function incremental.init()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return
  end
  incremental.nodes = { node }
  visual_select(node)
end

function incremental.increment()
  local node = incremental.nodes[#incremental.nodes]
  if not node then
    return incremental.init()
  end
  -- Walk up to the first ancestor that is strictly larger than the current node.
  local target = node:parent()
  while target and range_equal(target, node) do
    target = target:parent()
  end
  if target then
    table.insert(incremental.nodes, target)
    node = target
  end
  visual_select(node)
end

function incremental.decrement()
  if #incremental.nodes > 1 then
    table.remove(incremental.nodes)
  end
  local node = incremental.nodes[#incremental.nodes]
  if node then
    visual_select(node)
  end
end

return {
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    event = { "BufReadPre", "BufNewFile" },
    build = ":TSUpdate",
    config = function()
      -- Install parsers (async on the `main` branch).
      require("nvim-treesitter").install(ensure_installed)

      -- Enable highlighting + indentation per buffer. We use a broad FileType
      -- autocmd and guard with pcall so filetypes without an installed parser
      -- don't error.
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("treesitter_start", { clear = true }),
        callback = function(args)
          local buf = args.buf

          -- Keep the 100KB cutoff: skip treesitter for large files.
          local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
          if ok and stats and stats.size > max_filesize then
            return
          end

          -- Start treesitter highlighting only if a parser is available.
          -- `vim.treesitter.start` resolves the language from the buffer's
          -- filetype; pcall skips filetypes without an installed parser.
          -- Using treesitter (and not `:syntax on`) keeps legacy regex
          -- highlighting off, matching additional_vim_regex_highlighting = false.
          if pcall(vim.treesitter.start, buf) then
            -- Treesitter-based indentation, the `main`-branch way.
            vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
          end
        end,
      })

      -- Incremental selection mappings (manual reimplementation, see above).
      vim.keymap.set("n", "<C-s>", incremental.init, { desc = "Init treesitter selection" })
      vim.keymap.set("x", "<C-s>", incremental.increment, { desc = "Expand treesitter selection" })
      vim.keymap.set("x", "<bs>", incremental.decrement, { desc = "Shrink treesitter selection" })
    end,
  },

  -- nvim-ts-autotag is no longer configured through the treesitter options
  -- table; it gets its own spec and setup() call.
  {
    "windwp/nvim-ts-autotag",
    event = { "BufReadPre", "BufNewFile" },
    config = function()
      require("nvim-ts-autotag").setup()
    end,
  },
}
