return {
	"nvim-treesitter/nvim-treesitter",
	branch = "master",
	lazy = false,
	build = ":TSUpdate",
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = { 
				"lua", "cpp", "c_sharp", "rust", "markdown", "markdown_inline"
			}, -- Keep only stable parsers, add others manually later
			sync_install = false, -- Install parsers synchronously (only applied to `ensure_installed`)
			auto_install = false, -- Disable auto-install to prevent errors
			ignore_install = { "tsx", "typescript", "javascript" },  -- Temporarily ignore problematic parsers
			highlight = {
				enable = true,
				disable = function(lang, buf)
					-- Disable for large files
					local max_filesize = 100 * 1024 -- 100 KB
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						return true
					end
				end,
				additional_vim_regex_highlighting = false,
			},
			indent = {
				enable = true,
			},
			autotag = {
				enable = true,
			},
		})

		require("nvim-treesitter.install").prefer_git = true
		require("nvim-treesitter.install").compilers = { 
			"clang", "gcc", "g++", "zig", "cl", "cc" 
		}
	end,
}
