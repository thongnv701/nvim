return {
	"seblyng/roslyn.nvim",
	enabled = true,
	ft = "cs",
	config = function()
		vim.lsp.config("roslyn", {
			on_attach = function() end,
		})
	end,
}
