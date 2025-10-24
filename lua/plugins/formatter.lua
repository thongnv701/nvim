return {
	"mhartington/formatter.nvim",
	config = function()
		local util = require("formatter.util")

		require("formatter").setup({
			logging = true,
			log_level = vim.log.levels.WARN,
			filetype = {
				lua = {
					require("formatter.filetypes.lua").stylua,
					function()
						if util.get_current_buffer_file_name() == "special.lua" then
							return nil
						end
						return {
							exe = "stylua",
							args = {
								"--search-parent-directories",
								"--stdin-filepath",
								util.escape_path(util.get_current_buffer_file_path()),
								"--",
								"-",
							},
							stdin = true,
						}
					end,
				},
				cs = {
					require("formatter.filetypes.cs").csharpier,
				},
				python = {
					require("formatter.filetypes.python").black,
					require("formatter.filetypes.python").isort,
				},
				typescript = {
					require("formatter.filetypes.typescript").prettier,
				},
				typescriptreact = {
					require("formatter.filetypes.typescriptreact").prettier,
				},
				javascript = {
					require("formatter.filetypes.javascript").prettier,
				},
				javascriptreact = {
					require("formatter.filetypes.javascriptreact").prettier,
				},
				html = {
					require("formatter.filetypes.html").prettier,
				},
				css = {
					require("formatter.filetypes.css").prettier,
				},
				json = {
					require("formatter.filetypes.json").prettier,
				},
				rust = {
					require("formatter.filetypes.rust").rustfmt,
				},
			},
		})

		-- Keymaps
		vim.keymap.set("n", "<leader>fc", function()
			vim.cmd("Format")
		end, {
			desc = "Format file",
		})
		
		-- Format selected code in visual mode
		vim.keymap.set("v", "<leader>fc", function()
			vim.cmd("'<,'>Format")
		end, {
			desc = "Format selected code",
		})
	end,
}
