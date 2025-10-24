-- Working git blame plugin for Windows compatibility
return {
	"lewis6991/gitsigns.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	config = function()
		-- Windows compatibility settings
		if vim.fn.has("win32") == 1 then
			-- Set environment variables for Windows compatibility
			vim.env.LC_ALL = "C"
			vim.env.LANG = "C"
			vim.env.GIT_PAGER = ""
		end
		
		require("gitsigns").setup({
			-- Enable blame functionality
			current_line_blame = true,
			current_line_blame_opts = {
				virt_text = true,
				virt_text_pos = "eol", -- 'eol' | 'overlay' | 'right_align'
				delay = 500,
				ignore_whitespace = false,
				virt_text_priority = 100, -- Ensure blame text is visible over other virtual text
			},
			current_line_blame_formatter = " <author>, <author_time:%Y-%m-%d> • <summary>",
			-- Additional git features
			signs = {
				add = { text = "+" },
				change = { text = "~" },
				delete = { text = "_" },
				topdelete = { text = "‾" },
				changedelete = { text = "~" },
			},
			
			-- Keymaps for git blame
			on_attach = function(bufnr)
				local gs = package.loaded.gitsigns
				
				-- Toggle blame
				vim.keymap.set("n", "<leader>gb", gs.toggle_current_line_blame, {
					buffer = bufnr,
					desc = "Toggle git blame",
				})
				
				-- Show blame popup
				vim.keymap.set("n", "<leader>gB", function()
					gs.blame_line({ full = true })
				end, {
					buffer = bufnr,
					desc = "Show full git blame",
				})
				
				-- Navigate hunks
				vim.keymap.set("n", "]c", function()
					if vim.wo.diff then return "]c" end
					vim.schedule(function() gs.next_hunk() end)
					return "<Ignore>"
				end, { expr = true, buffer = bufnr, desc = "Next hunk" })
				
				vim.keymap.set("n", "[c", function()
					if vim.wo.diff then return "[c" end
					vim.schedule(function() gs.prev_hunk() end)
					return "<Ignore>"
				end, { expr = true, buffer = bufnr, desc = "Previous hunk" })
				
				-- Stage hunk
				vim.keymap.set("n", "<leader>gs", gs.stage_hunk, {
					buffer = bufnr,
					desc = "Stage hunk",
				})
				
				-- Reset hunk
				vim.keymap.set("n", "<leader>gr", gs.reset_hunk, {
					buffer = bufnr,
					desc = "Reset hunk",
				})
			end,
		})
		
		-- Custom highlight for blame
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = function()
				vim.api.nvim_set_hl(0, "GitSignsCurrentLineBlame", {
					fg = "#808080",
					italic = true,
				})
			end,
		})
		
		-- Show status when toggling
		vim.api.nvim_create_autocmd("User", {
			pattern = "GitSignsToggle",
			callback = function()
				vim.notify("🔍 Git blame toggled", vim.log.levels.INFO)
			end,
		})
	end,
}
