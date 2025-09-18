return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
	config = function()
		require("neo-tree").setup({
			close_if_last_window = true,
			enable_git_status = true,
			enable_diagnostics = true,
			filesystem = {
				follow_current_file = {
					enabled = true,
				},
				use_libuv_file_watcher = true,
			},
			window = {
				width = 50,
			},
		})

		vim.keymap.set("n", "<leader>e", ":Neotree toggle<CR>", {
			desc = "Toggle Explorer",
			silent = true,
		})
		vim.keymap.set("n", "<leader>ef", ":Neotree focus<CR>", {
			desc = "Focus Explorer",
			silent = true,
		})
	end,
}
