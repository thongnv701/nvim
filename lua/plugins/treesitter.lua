-- In lua/plugins/treesitter.lua
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	lazy = false,
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = {}, -- EMPTY - manual install only
			sync_install = false,
			auto_install = false,  -- CRITICAL - prevents auto-compilation conflicts
			ignore_install = { "tsx", "typescript", "javascript", "vimdoc" },
			
			highlight = { enable = true },
			indent = { enable = true },
		})

		-- Windows-specific fixes
		require("nvim-treesitter.install").prefer_git = false
		require("nvim-treesitter.install").compilers = { "zig", "cl", "clang", "gcc" }
		
		-- Prevent concurrent installations
		vim.g.loaded_tree_sitter_install = 1
	end,
}