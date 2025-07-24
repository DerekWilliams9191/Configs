return {
  "nvim-lua/plenary.nvim", -- lua functions that many plugins use
  "christoomey/vim-tmux-navigator", -- tmux & split window navigation
  "mfussenegger/nvim-lint", -- linting support
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {
      -- add any options here, or leave empty to use defaults
    },
  },
}

