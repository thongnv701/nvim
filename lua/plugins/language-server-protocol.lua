return {
	{
		"neovim/nvim-lspconfig",
		dependencies = { "williamboman/mason.nvim", "hrsh7th/cmp-nvim-lsp", "seblyng/roslyn.nvim" },
		config = function()
			-- Capabilities for completion
			local capabilities = vim.lsp.protocol.make_client_capabilities()
			local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
			if cmp_nvim_lsp_ok then
				capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
			end

			-- Common on_attach
			local function on_attach(client, bufnr)
				vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"
				local bufopts = { noremap = true, silent = true, buffer = bufnr }
				vim.keymap.set(
					"n",
					"gd",
					vim.lsp.buf.definition,
					vim.tbl_extend("force", bufopts, { desc = "Go to definition" })
				)
				vim.keymap.set(
					"n",
					"gD",
					vim.lsp.buf.declaration,
					vim.tbl_extend("force", bufopts, { desc = "Go to declaration" })
				)
				vim.keymap.set("n", "gi", function()
					require("telescope.builtin").lsp_implementations({ show_line = false })
				end, vim.tbl_extend("force", bufopts, { desc = "Go to implementation" }))
				vim.keymap.set("n", "gr", function()
					require("telescope.builtin").lsp_references({ show_line = false })
				end, vim.tbl_extend("force", bufopts, { desc = "Go to references" }))
				vim.keymap.set(
					"n",
					"K",
					vim.lsp.buf.hover,
					vim.tbl_extend("force", bufopts, { desc = "Hover documentation" })
				)
				vim.keymap.set(
					"n",
					"<leader>ca",
					vim.lsp.buf.code_action,
					vim.tbl_extend("force", bufopts, { desc = "Code action" })
				)
				vim.keymap.set(
					"n",
					"<leader>rn",
					vim.lsp.buf.rename,
					vim.tbl_extend("force", bufopts, { desc = "Rename" })
				)
				vim.keymap.set(
					"n",
					"<leader>fd",
					vim.diagnostic.open_float,
					vim.tbl_extend("force", bufopts, { desc = "Show diagnostics" })
				)
				vim.keymap.set("n", "<leader>f", function()
					vim.lsp.buf.format({ async = true })
				end, vim.tbl_extend("force", bufopts, { desc = "Format" }))
			end

			-- Diagnostics UI
			vim.diagnostic.config({
				virtual_text = { prefix = "●", source = "always", spacing = 4 },
				signs = {
					text = {
						[vim.diagnostic.severity.ERROR] = "✘",
						[vim.diagnostic.severity.WARN] = "▲",
						[vim.diagnostic.severity.INFO] = "⚑",
						[vim.diagnostic.severity.HINT] = "»",
					},
				},
				underline = true,
				update_in_insert = true,
				severity_sort = true,
			})

			-- Helper: compute root
			local function get_root(buf)
				local bufname = vim.api.nvim_buf_get_name(buf)
				local patterns = { ".git", "pom.xml", "build.gradle", "build.gradle.kts", "mvnw", "gradlew" }
				return vim.fs.root(bufname, patterns) or vim.uv.cwd()
			end

			-- Define servers with commands and settings
			local servers = {
				lua_ls = {
					cmd = { "lua-language-server" },
					filetypes = { "lua" },
					settings = {
						Lua = {
							runtime = { version = "LuaJIT", path = vim.split(package.path, ";") },
							diagnostics = { globals = { "vim" } },
							workspace = { library = vim.api.nvim_get_runtime_file("", true), checkThirdParty = false },
							telemetry = { enable = false },
							completion = { callSnippet = "Replace" },
						},
					},
				},
				clangd = { cmd = { "clangd" }, filetypes = { "c", "cpp", "objc", "objcpp" } },
				rust_analyzer = {
					cmd = { "rust-analyzer" },
					filetypes = { "rust" },
					settings = {
						["rust-analyzer"] = {
							cargo = { loadOutDirsFromCheck = true },
							procMacro = { enable = true },
							check = { command = "clippy" },
							diagnostics = { experimental = { enable = true } },
							assist = { emitMustUse = true },
						},
					},
				},
				pyright = {
					cmd = { "pyright-langserver", "--stdio" },
					filetypes = { "python" },
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
					cmd = { "typescript-language-server", "--stdio" },
					filetypes = { "typescript", "typescriptreact", "javascript", "javascriptreact" },
				},
				-- jdtls is handled in ftplugin/java.lua
			}

			-- Start LSP per filetype on buffer enter
			for name, cfg in pairs(servers) do
				vim.api.nvim_create_autocmd("FileType", {
					pattern = cfg.filetypes,
					callback = function(args)
						local root_dir = get_root(args.buf)
						vim.lsp.start({
							name = name,
							cmd = cfg.cmd,
							root_dir = root_dir,
							capabilities = capabilities,
							on_attach = on_attach,
							settings = cfg.settings,
						})
					end,
				})
			end

			-- Fallback keymaps
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, { desc = "Go to implementation" })
			vim.keymap.set("n", "gr", require("telescope.builtin").lsp_references, { desc = "Go to references" })
			vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, { desc = "Code actions" })
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, { desc = "Rename symbol" })
			vim.keymap.set("n", "<leader>fd", vim.diagnostic.open_float, { desc = "Show diagnostics" })
		end,
	},
	{
		"mfussenegger/nvim-jdtls",
		ft = { "java" },
	},
}
