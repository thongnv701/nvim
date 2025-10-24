return {
	"APZelos/blamer.nvim",
	event = "VeryLazy",
	config = function()
		-- Windows compatibility fix for LC_ALL issue
		if vim.fn.has("win32") == 1 then
			-- Set environment variables for Windows compatibility
			vim.env.LC_ALL = "C"
			vim.env.LANG = "C"
		end
		
		-- Disable blamer on startup due to Windows compatibility issues
		-- Use git-blame.lua instead for better Windows support
		vim.g.blamer_enabled = 0
		
		-- Delay in milliseconds for blame message to show
		-- Lower values may cause performance issues
		vim.g.blamer_delay = 500
		
		-- Show in visual modes (selection)
		vim.g.blamer_show_in_visual_modes = 1
		
		-- Show in insert modes
		vim.g.blamer_show_in_insert_modes = 1
		
		-- Prefix for blame messages
		vim.g.blamer_prefix = " > "
		
		-- Template for blame message
		-- Available: <author>, <author-mail>, <author-time>, <committer>, 
		-- <committer-mail>, <committer-time>, <summary>, <commit-short>, <commit-long>
		vim.g.blamer_template = "<committer>, <committer-time> • <summary>"
		
		-- Date format for time fields
		vim.g.blamer_date_format = "%d/%m/%y %H:%M"
		
		-- Show relative time (e.g., "2 hours ago")
		vim.g.blamer_relative_time = 1
		
		-- Custom highlight for blame messages
		vim.api.nvim_create_autocmd("ColorScheme", {
			pattern = "*",
			callback = function()
				vim.api.nvim_set_hl(0, "Blamer", {
					fg = "#808080",
					italic = true,
				})
			end,
		})
		
		-- Keymaps for blamer
		vim.keymap.set("n", "<leader>gb", ":BlamerToggle<CR>", {
			desc = "Toggle git blame",
		})
		
		vim.keymap.set("n", "<leader>gB", ":BlamerShow<CR>", {
			desc = "Show git blame",
		})
		
		vim.keymap.set("n", "<leader>gH", ":BlamerHide<CR>", {
			desc = "Hide git blame",
		})
		
		-- Windows-specific git blame configuration
		if vim.fn.has("win32") == 1 then
			-- Override git command for Windows compatibility
			vim.g.blamer_git_command = "git"
			
			-- Set additional Windows environment variables
			vim.env.GIT_PAGER = ""
			vim.env.GIT_CONFIG_NOSYSTEM = "1"
		end
		
		-- Auto-disable blamer in non-git repositories
		vim.api.nvim_create_autocmd("DirChanged", {
			pattern = "*",
			callback = function()
				local git_dir = vim.fn.finddir(".git", ".;")
				if git_dir == "" then
					vim.cmd("BlamerHide")
				end
			end,
		})
		
		-- Show blamer status in statusline (optional)
		vim.api.nvim_create_autocmd("User", {
			pattern = "BlamerEnabled",
			callback = function()
				vim.notify("🔍 Git blame enabled", vim.log.levels.INFO)
			end,
		})
		
		vim.api.nvim_create_autocmd("User", {
			pattern = "BlamerDisabled", 
			callback = function()
				vim.notify("🔍 Git blame disabled", vim.log.levels.INFO)
			end,
		})
	end,
}
