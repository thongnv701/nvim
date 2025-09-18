return {
	"neovim/nvim-lspconfig",
	dependencies = { "williamboman/mason.nvim", "hrsh7th/cmp-nvim-lsp", "seblyng/roslyn.nvim" },
	config = function()
		-- LSP setup
		local lspconfig = require("lspconfig")

		-- Setup capabilities cho completion
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
		if cmp_nvim_lsp_ok then
			capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
		end

		-- Setup LSP servers trực tiếp
		local servers = {
			lua_ls = {
				settings = {
					Lua = {
						diagnostics = {
							globals = { "vim" },
						},
						workspace = {
							library = vim.api.nvim_get_runtime_file("", true),
						},
					},
				},
			},
			clangd = {},
			rust_analyzer = {
				settings = {
					["rust-analyzer"] = {
						check = {
							command = "clippy",
						},
					},
				},
			},
			pyright = {
				settings = {
					python = {
						analysis = {
							autoSearchPaths = true,
							useLibraryCodeForTypes = true,
							diagnosticMode = "workspace",
						},
					},
				},
			},
			ts_ls = {
				-- Simple, basic configuration without complex settings
				filetypes = {
					"typescript",
					"typescriptreact", 
					"javascript",
					"javascriptreact",
				},
			},
		}

		vim.diagnostic.config({
			virtual_text = {
				prefix = "●",
				source = "always",
				spacing = 4,
			},
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = "✘",
					[vim.diagnostic.severity.WARN] = "▲",
					[vim.diagnostic.severity.INFO] = "⚑",
					[vim.diagnostic.severity.HINT] = "»",
				},
			},
			underline = true,
			update_in_insert = false,
			severity_sort = true,
		})

		for server_name, server_config in pairs(servers) do
			server_config.capabilities = capabilities
			lspconfig[server_name].setup(server_config)
		end

		-- Keymaps
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, {
			desc = "Go to definition",
		})
		vim.keymap.set("n", "gi", vim.lsp.buf.implementation, {
			desc = "Go to implementation",
		})
		vim.keymap.set("n", "gu", vim.lsp.buf.references, {
			desc = "Go to references",
		})
		vim.keymap.set("n", "ca", vim.lsp.buf.code_action, {
			desc = "Language Server Protocol code action",
		})
		vim.keymap.set("n", "K", vim.lsp.buf.hover, {
			desc = "Hover documentation",
		})
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, {
			desc = "Code actions",
		})
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, {
			desc = "Rename symbol",
		})
		vim.keymap.set("n", "<leader>fd", vim.diagnostic.open_float, {
			desc = "Show diagnostics",
		})
	end,
}
