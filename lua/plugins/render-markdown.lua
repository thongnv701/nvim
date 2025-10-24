return {
	"MeanderingProgrammer/render-markdown.nvim",
	version = false,
	ft = { "markdown", "md", "codecompanion" },
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"echasnovski/mini.icons",
	},
	config = function()
		require("render-markdown").setup({
			file_types = { "markdown", "markdown_inline", "codecompanion" },
			-- Enable by default
			enabled = true,
			-- Optional: Add some visual enhancements
			headings = {
				enable = true,
				sign = true,
				position = "overlay",
			},
			code = {
				enable = true,
				sign = true,
				style = "full",
			},
			-- Debug mode to see what's happening
			log_level = vim.log.levels.INFO,
		})
		
		-- Create a keybinding to manually toggle
		vim.keymap.set("n", "<leader>mr", "<cmd>RenderMarkdown toggle<cr>", 
			{ desc = "Toggle Markdown Render" })
	end,
}
