return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("nvim-treesitter.configs").setup({
			textobjects = {
				select = {
					enable = true,
					lookahead = true, -- Jump forward to textobject like targets.vim
					keymaps = {
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						["ic"] = "@class.inner",
						["ab"] = "@block.outer", -- may not exist for all languages
						["ib"] = "@block.inner",
					},
					selection_modes = {
						["@function.outer"] = "V", -- linewise for whole function
						["@function.inner"] = "v", -- charwise for body
						["@class.outer"] = "V",
						["@class.inner"] = "V",
					},
					include_surrounding_whitespace = true,
				},
			},
		})

		-- Convenience shortcuts: select method/function body or entire method quickly
		vim.keymap.set("n", "<leader>mm", "vif", { desc = "Select method body" })
		vim.keymap.set("n", "<leader>ma", "vaf", { desc = "Select entire method" })
	end,
}


