return {
	"akinsho/bufferline.nvim",
	version = "*",
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		vim.opt.termguicolors = true
		require("bufferline").setup({})

		-- Keymaps
		vim.keymap.set("n", "<S-l>", ":BufferLineCycleNext<CR>", {
			desc = "Next buffer",
		})
		vim.keymap.set("n", "<S-h>", ":BufferLineCyclePrev<CR>", {
			desc = "Previous buffer",
		})
        vim.keymap.set("n", "<leader>x", ":bd<CR>", {
			desc = "Close current buffer",
		})

	end,
}
