local M = {}
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

	vim.opt.shortmess:append("c")
	vim.opt.whichwrap:append("<,>,[,],h,l")
end

return M
