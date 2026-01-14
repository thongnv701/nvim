-- In lua/plugins/treesitter.lua
return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	lazy = false,
	config = function()
		-- Register wgsl file type
		vim.filetype.add({ extension = { wgsl = "wgsl", wesl = "wesl" } })

		-- Configure wgsl parser
		local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
		parser_config.wgsl = {
			install_info = {
				url = "https://github.com/szebniok/tree-sitter-wgsl",
				files = { "src/parser.c" },
			},
		}

		require("nvim-treesitter.configs").setup({
			ensure_installed = { "wgsl" },
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