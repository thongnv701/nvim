local M = {}

-- Helper function to create augroup
local function augroup(name)
	return vim.api.nvim_create_augroup(name, { clear = true })
end

function M.setup()
	local options = {
		number = true,
		relativenumber = true,
		mouse = "a",
		ignorecase = true,
		smartcase = true,
		hlsearch = false,
		wrap = true,
		breakindent = true,
		tabstop = 4,
		shiftwidth = 4,
		expandtab = true,
		termguicolors = true,
		cursorline = true,
		scrolloff = 8,
		sidescrolloff = 8,
		signcolumn = "yes",
		splitbelow = true,
		splitright = true,
		timeoutlen = 300,
		updatetime = 300,
		completeopt = { "menuone", "noselect" },
		clipboard = "unnamedplus",
	}

	for k, v in pairs(options) do
		vim.opt[k] = v
	end

	-- Fix ShaDa file locking issue
	vim.opt.shadafile = vim.fn.expand("~/.local/share/nvim/shada/main.shada")

	vim.opt.shortmess:append("c")
	vim.opt.whichwrap:append("<,>,[,],h,l")

	-- Configure filetype detection for YAML and XML files
	vim.filetype.add({
		extension = {
			yaml = "yaml",
			yml = "yaml",
			xml = "xml",
			xsd = "xml",
			xsl = "xml",
			xslt = "xml",
			wsdl = "xml",
			svg = "xml",
		},
		pattern = {
			[".*%.conf"] = "conf",
			[".*%.env.*"] = "sh", -- For .env files
		},
	})
	-- Disable Copilot if a specific file exists in the project root
	vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
		group = augroup("copilot_disable"),
		callback = function()
			-- Check if .disable-copilot file exists in the project root
			local project_root = vim.fs.dirname(
				vim.fs.find(
					{ ".git", ".disable-copilot", "Makefile", "CMakeLists.txt", "compile_commands.json" },
					{ upward = true }
				)[1] or vim.fn.getcwd()
			)

			if project_root then
				local disable_file = project_root .. "/.disable-copilot"
				if vim.fn.filereadable(disable_file) == 1 then
					-- Set the global variable to disable Copilot for this session
					vim.g.copilot_enabled = false
					-- Try to disable using command immediately
					vim.cmd("silent! Copilot disable")

					-- Also disable for the current buffer specifically
					vim.b.copilot_enabled = false

					-- Try to disable when plugin is available using schedule
					vim.schedule(function()
						local ok, copilot = pcall(require, "copilot")
						if ok and copilot and copilot.disable then
							copilot.disable()
						else
							vim.cmd("silent! Copilot disable")
						end
					end)
				else
					-- If the file doesn't exist but Copilot was disabled, re-enable it
					if vim.g.copilot_enabled == false then
						vim.g.copilot_enabled = true
						vim.cmd("silent! Copilot enable")
					end
				end
			end
		end,
		desc = "Disable Copilot if .disable-copilot file exists in project root",
	})
end

return M
