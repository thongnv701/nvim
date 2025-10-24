-- Guarded Treesitter start for Lua to avoid errors when parser isn't installed
local ok_parsers, parsers = pcall(require, "nvim-treesitter.parsers")
if ok_parsers and parsers.has_parser("lua") then
	pcall(vim.treesitter.start)
end
