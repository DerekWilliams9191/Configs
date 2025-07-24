return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	dependencies = {
		-- Useful for getting pretty icons, but requires a Nerd Font.
		{ "nvim-tree/nvim-web-devicons" },
	},

	-- [[ Configure require("snacks") ]]
	-- See `:help snacks-init`
	opts = {
		lazygit = {},
		dim = {},
		explorer = {},
		gitbrowse = {},
		image = {},
		quickfile = {},
		scratch = {},
		scroll = {},
		words = {},

		animate = {
			duration = 20, -- ms per step
			easing = "linear",
			fps = 60, -- frames per second. Global setting for all animations
		},

		picker = {
			sources = {
				explorer = {
					auto_close = false,
					hidden = true,
					ignored = true,
					exclude = {
						".DS_Store",
						"*~",
						"*.tmp",
						"*.swp",
					},
				},
			},
		},
	},
	keys = {
		-- [[ Terminal ]]
		{
			"<c-/>",
			function()
				require("snacks").terminal()
			end,
			desc = "Toggle Terminal",
		},
		{ "<C-/>", "<cmd>close<cr>", desc = "Hide Terminal", mode = "t" },

		-- [[ Code ]]
		{
			"<leader>cR",
			function()
				require("snacks").rename.rename_file()
			end,
			desc = "Rename File",
		},
		{
			"]]",
			function()
				require("snacks").words.jump(vim.v.count1)
			end,
			desc = "Next Reference",
			mode = { "n", "t" },
		},
		{
			"[[",
			function()
				require("snacks").words.jump(-vim.v.count1)
			end,
			desc = "Prev Reference",
			mode = { "n", "t" },
		},

		-- [[ Git ]]
		{
			"<leader>gb",
			function()
				require("snacks").git.blame_line({ count = 20, interactive = true })
			end,
			desc = "Git Blame Line",
		},
		{
			"<leader>gB",
			function()
				require("snacks").gitbrowse()
			end,
			desc = "Git Browse",
			mode = { "n", "v" },
		},
		{
			"<leader>gY",
			function()
				require("snacks").gitbrowse({
					open = function(url)
						vim.fn.setreg("+", url)
						require("snacks").notify("Copied Git URL")
					end,
					notify = false,
				})
			end,
			desc = "Git Browse (copy)",
		},
		{
			"<leader>lg",
			function()
				require("snacks").lazygit()
			end,
			desc = "LazyGit",
		},
		{
			"<leader>gl",
			function()
				require("snacks").lazygit.log()
			end,
			desc = "LazyGit Log",
		},
		{
			"<leader>gf",
			function()
				require("snacks").lazygit.log_file()
			end,
			desc = "LazyGit Log (Current File)",
		},

		--[[ Pickers ]]
		-- See `:help snacks-pickers-sources`
		-- top pickers & explorer
		{
			"<leader><leader>",
			function()
				require("snacks").picker.buffers()
			end,
			desc = "Find existing buffers",
		},
		{
			"<leader>/",
			function()
				require("snacks").picker.lines()
			end,
			desc = "Fuzzily search in current buffer",
		},
		{
			"<leader>:",
			function()
				require("snacks").picker.command_history()
			end,
			desc = "Command History",
		},
		{
			"<leader>ee",
			function()
				require("snacks").picker.explorer()
			end,
			desc = "Snacks Explorer",
		},
		-- search
		{
			"<leader>s.",
			function()
				require("snacks").picker.recent()
			end,
			desc = 'Recent Files ("." for repeat)',
		},
		{
			"<leader>sc",
			function()
				require("snacks").picker.commands()
			end,
			desc = "Commands",
		},
		{
			"<leader>sd",
			function()
				require("snacks").picker.diagnostics()
			end,
			desc = "Diagnostics",
		},
		{
			"<leader>sf",
			function()
				require("snacks").picker.smart()
			end,
			desc = "Files",
		},
		{
			"<leader>sg",
			function()
				require("snacks").picker.grep()
			end,
			desc = "Grep",
		},
		{
			"<leader>sh",
			function()
				require("snacks").picker.help()
			end,
			desc = "Help",
		},
		{
			"<leader>sk",
			function()
				require("snacks").picker.keymaps()
			end,
			desc = "Keymaps",
		},
		{
			"<leader>sn",
			function()
				require("snacks").picker.files({ cwd = vim.fn.stdpath("config") })
			end,
			desc = "Neovim Files",
		},
		{
			"<leader>sr",
			function()
				require("snacks").picker.resume()
			end,
			desc = "Resume",
		},
		{
			"<leader>ss",
			function()
				require("snacks").picker.pickers()
			end,
			desc = "Snacks Pickers",
		},
		{
			"<leader>sw",
			function()
				require("snacks").picker.grep_word()
			end,
			desc = "Current Word",
			mode = { "n", "x" },
		},
		{
			"<leader>uC",
			function()
				require("snacks").picker.colorschemes()
			end,
			desc = "Colorscheme with Preview",
		},
		-- find
		{
			"<leader>fb",
			function()
				require("snacks").picker.buffers()
			end,
			desc = "Buffers",
		},
		{
			"<leader>ff",
			function()
				require("snacks").picker.files({
					ignored = false,
					hidden = true,
					follow = true,
				})
			end,
			desc = "Files (including hidden/ignored)",
		},
		{
			"<leader>fg",
			function()
				require("snacks").picker.git_files()
			end,
			desc = "Git Files",
		},
		{
			"<leader>fn",
			function()
				require("snacks").picker.files({ cwd = vim.fn.stdpath("config") })
			end,
			desc = "Neovim Files",
		},
		{
			"<leader>fp",
			function()
				require("snacks").picker.projects()
			end,
			desc = "Projects",
		},
		{
			"<leader>fr",
			function()
				require("snacks").picker.recent()
			end,
			desc = "Recent",
		},
	},
}
