return {
	"numToStr/Comment.nvim",
	event = { "BufReadPost", "BufNewFile" },
	dependencies = {
		-- For better support of JSX, TSX, Vue, HTML embedded scripts
		"JoosepAlviste/nvim-ts-context-commentstring",
	},
	config = function()
		-- Setup ts_context_commentstring for embedded languages
		require("ts_context_commentstring").setup({
			enable_autocmd = false,
		})

		require("Comment").setup({
			-- Add a space between comment and the line
			padding = true,
			-- Whether the cursor should stay at its position
			sticky = true,
			-- Lines to be ignored while (un)comment
			ignore = "^$", -- ignore empty lines
			-- LHS of toggle mappings in NORMAL mode
			toggler = {
				-- Line-comment toggle keymap
				line = "gcc",
				-- Block-comment toggle keymap
				block = "gbc",
			},
			-- LHS of operator-pending mappings in NORMAL and VISUAL mode
			opleader = {
				-- Line-comment keymap (works with motions and visual)
				line = "gc",
				-- Block-comment keymap
				block = "gb",
			},
			-- LHS of extra mappings
			extra = {
				-- Add comment on the line above
				above = "gcO",
				-- Add comment on the line below
				below = "gco",
				-- Add comment at the end of line
				eol = "gcA",
			},
			-- Enable keybindings
			mappings = {
				-- Operator-pending mapping (gc in visual mode, gc{motion} in normal)
				basic = true,
				-- Extra mappings (gcO, gco, gcA)
				extra = true,
			},
			-- Function to call before (un)comment
			pre_hook = require("ts_context_commentstring.integrations.comment_nvim").create_pre_hook(),
		})

		-- Custom keymaps for Ctrl+/ (common shortcut from other editors)
		local api = require("Comment.api")

		-- Ctrl+/ in normal mode - toggle comment on current line
		vim.keymap.set("n", "<C-/>", api.toggle.linewise.current, {
			desc = "Toggle comment on current line",
		})

		-- Ctrl+/ in visual mode - toggle comment on selected lines
		vim.keymap.set("v", "<C-/>", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", {
			desc = "Toggle comment on selected lines",
		})

		-- Alternative: leader+/ for terminals that don't support Ctrl+/
		vim.keymap.set("n", "<leader>/", api.toggle.linewise.current, {
			desc = "Toggle comment on current line",
		})

		vim.keymap.set("v", "<leader>/", "<ESC><cmd>lua require('Comment.api').toggle.linewise(vim.fn.visualmode())<CR>", {
			desc = "Toggle comment on selected lines",
		})
	end,
}
