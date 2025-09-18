return {
	"williamboman/mason-lspconfig.nvim",
	dependencies = { "williamboman/mason.nvim" },
	config = function()
		require("mason-lspconfig").setup({
			ensure_installed = { "lua_ls", "clangd", "rust_analyzer", "ts_ls" },
			automatic_installation = true,
		})
	end,
}
