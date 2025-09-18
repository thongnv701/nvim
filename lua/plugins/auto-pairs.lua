return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		require("nvim-autopairs").setup({
			check_ts = true,
			ts_config = {
				lua = { "string", "source" },
				javascript = { "string", "template_string" },
				typescript = { "string", "template_string" },
				javascriptreact = { "string", "template_string" },
				typescriptreact = { "string", "template_string" },
				java = false,
				rust = { "string", "raw_string" },
				c_sharp = { "string" },
			},
		})
	end,
}
