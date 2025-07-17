-- set leader key to space
vim.g.mapleader = " "

local keymap = vim.keymap -- for conciseness

---------------------
-- General Keymaps -------------------

-- use jk to exit insert mode
keymap.set("i", "jk", "<ESC>", { desc = "Exit insert mode with jk" })

-- clear search highlights
keymap.set("n", "<leader>nh", ":nohl<CR>", { desc = "Clear search highlights" })

-- delete single character without copying into register
-- keymap.set("n", "x", '"_x')

-- increment/decrement numbers
keymap.set("n", "<leader>+", "<C-a>", { desc = "Increment number" }) -- increment
keymap.set("n", "<leader>-", "<C-x>", { desc = "Decrement number" }) -- decrement

-- window management
keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" }) -- split window vertically
keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" }) -- split window horizontally
keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" }) -- make split windows equal width & height
keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" }) -- close current split window

keymap.set("n", "<leader>tc", "<cmd>tabnew<CR>", { desc = "Open new tab" }) -- open new tab
keymap.set("n", "<leader>tx", "<cmd>tabclose<CR>", { desc = "Close current tab" }) -- close current tab
keymap.set("n", "<leader>tn", "<cmd>tabn<CR>", { desc = "Go to next tab" }) --  go to next tab
keymap.set("n", "<leader>tp", "<cmd>tabp<CR>", { desc = "Go to previous tab" }) --  go to previous tab
keymap.set("n", "<leader>tf", "<cmd>tabnew %<CR>", { desc = "Open current buffer in new tab" }) --  move current buffer to new tab

-- tab navigation by number
keymap.set("n", "<leader>t1", "1gt", { desc = "Go to tab 1" })
keymap.set("n", "<leader>t2", "2gt", { desc = "Go to tab 2" })
keymap.set("n", "<leader>t3", "3gt", { desc = "Go to tab 3" })
keymap.set("n", "<leader>t4", "4gt", { desc = "Go to tab 4" })
keymap.set("n", "<leader>t5", "5gt", { desc = "Go to tab 5" })
keymap.set("n", "<leader>t6", "6gt", { desc = "Go to tab 6" })
keymap.set("n", "<leader>t7", "7gt", { desc = "Go to tab 7" })
keymap.set("n", "<leader>t8", "8gt", { desc = "Go to tab 8" })
keymap.set("n", "<leader>t9", "9gt", { desc = "Go to tab 9" })

