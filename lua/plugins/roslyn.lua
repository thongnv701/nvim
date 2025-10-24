return {
	"seblyng/roslyn.nvim",
	enabled = true,
	ft = "cs",
	config = function()
		-- Setup capabilities for completion
		local capabilities = vim.lsp.protocol.make_client_capabilities()
		local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
		if cmp_nvim_lsp_ok then
			capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
		end

		-- Common on_attach function for all LSP servers
		local on_attach = function(client, bufnr)
			-- Enable completion triggered by <c-x><c-o>
			vim.bo[bufnr].omnifunc = "v:lua.vim.lsp.omnifunc"

			-- Buffer local mappings (these will override global ones)
			local bufopts = { noremap = true, silent = true, buffer = bufnr }
			
			vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", bufopts, { desc = "Go to definition" }))
			vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", bufopts, { desc = "Go to declaration" }))
			vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", bufopts, { desc = "Go to implementation" }))
			
			-- Use Telescope for references instead of the default LSP references window
			vim.keymap.set("n", "gr", function()
				require("telescope.builtin").lsp_references({
					show_line = false,
				})
			end, vim.tbl_extend("force", bufopts, { desc = "Go to references" }))
			
			vim.keymap.set("n", "gu", function()
				require("telescope.builtin").lsp_references({
					show_line = false,
				})
			end, vim.tbl_extend("force", bufopts, { desc = "Go to references (alt)" }))
			
			vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", bufopts, { desc = "Hover documentation" }))
			vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", bufopts, { desc = "Code action" }))
			vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", bufopts, { desc = "Rename" }))
			vim.keymap.set("n", "<leader>fd", vim.diagnostic.open_float, vim.tbl_extend("force", bufopts, { desc = "Show diagnostics" }))
			vim.keymap.set("n", "<leader>f", function()
				vim.lsp.buf.format({ async = true })
			end, vim.tbl_extend("force", bufopts, { desc = "Format" }))
		end

		-- Initialize roslyn.nvim - this sets up the LSP configuration
		local roslyn_ok, roslyn = pcall(require, "roslyn")
		if not roslyn_ok then
			vim.notify("roslyn.nvim: Failed to load", vim.log.levels.ERROR)
			return
		end

		-- Setup roslyn.nvim with our custom on_attach and capabilities
		roslyn.setup({
			on_attach = on_attach,
			capabilities = capabilities,
		})

		-- Helper: compute root for C# projects
		local function get_root(buf)
			local bufname = vim.api.nvim_buf_get_name(buf)
			local patterns = { 
				".git", 
				".csproj", 
				".sln", 
				"Directory.Build.props", 
				"Directory.Build.targets", 
				"project.json",
				"global.json"
			}
			return vim.fs.root(bufname, patterns) or vim.uv.cwd()
		end

		-- Start LSP on FileType autocmd
		-- roslyn.nvim will handle the cmd setup automatically after setup() is called
		vim.api.nvim_create_autocmd("FileType", {
			pattern = { "cs", "csx" },
			callback = function(args)
				local root_dir = get_root(args.buf)
				
				-- Use vim.lsp.start() with the roslyn name registered by roslyn.nvim
				-- roslyn.nvim.setup() has already registered the "roslyn" config with proper cmd
				vim.lsp.start({
					name = "roslyn",
					root_dir = root_dir,
					capabilities = capabilities,
					on_attach = on_attach,
				})
			end,
		})
	end,
}
