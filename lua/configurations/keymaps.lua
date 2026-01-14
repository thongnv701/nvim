local M = {}

local function map(mode, lhs, rhs, opts)
	local options = {
		noremap = true,
		silent = true,
	}
	if opts then
		for k, v in pairs(opts) do
			options[k] = v
		end
	end

	vim.keymap.set(mode, lhs, rhs, options)
end

function M.setup()
	vim.g.mapleader = " "
	vim.g.maplocalleader = " "

	-- Map jk to ESC in insert mode
	map("i", "jk", "<Esc>")

	-- Select all text with Ctrl+A
	map("n", "<C-a>", "ggVG", {
		desc = "Select all text",
	})

	-- Di chuyển giữa các cửa sổ
	map("n", "<C-h>", "<C-w>h")
	map("n", "<C-j>", "<C-w>j")
	map("n", "<C-k>", "<C-w>k")
	map("n", "<C-l>", "<C-w>l")

	-- Thay đổi kích thước cửa sổ
	map("n", "<C-Up>", ":resize -2<CR>")
	map("n", "<C-Down>", ":resize +2<CR>")
	map("n", "<C-Left>", ":vertical resize -2<CR>")
	map("n", "<C-Right>", ":vertical resize +2<CR>")

	-- Di chuyển văn bản trong Visual mode
	map("v", "<A-j>", ":m .+1<CR>==")
	map("v", "<A-k>", ":m .-2<CR>==")

	-- Giữ văn bản đã chọn khi thụt lề
	map("v", "<", "<gv")
	map("v", ">", ">gv")

	-- Tắt highlight sau khi tìm kiếm
	map("n", "<Esc>", ":noh<CR>")

	-- Lưu file
	map("n", "<C-s>", ":w<CR>")

	-- Split windows
	map("n", "<leader>sv", ":vsplit<CR>", {
		desc = "Split vertical",
	})
	map("n", "<leader>sh", ":split<CR>", {
		desc = "Split horizontal",
	})

	-- Buffer and window management
	map("n", "<leader>q", ":bd<CR>", {
		desc = "Close current buffer",
	})
	map("n", "<leader>Q", ":qa!<CR>", {
		desc = "Force quit all",
	})

	-- Additional buffer navigation
	map("n", "<leader>bn", ":bnext<CR>", {
		desc = "Next buffer",
	})
	map("n", "<leader>bp", ":bprevious<CR>", {
		desc = "Previous buffer",
	})
	map("n", "<leader>bd", ":bd<CR>", {
		desc = "Delete buffer",
	})
	map("n", "<leader>ba", ":%bd|e#<CR>", {
		desc = "Close all buffers except current",
	})

	-- Error/Diagnostic Navigation (using <leader>e and <leader>p)
	map("n", "<leader>e", function()
		vim.diagnostic.goto_next({ severity = vim.diagnostic.severity.ERROR })
	end, {
		desc = "Jump to next error",
	})
	map("n", "<leader>p", function()
		vim.diagnostic.goto_prev({ severity = vim.diagnostic.severity.ERROR })
	end, {
		desc = "Jump to previous error",
	})

	-- All diagnostics (errors + warnings)
	map("n", "<leader>ne", function()
		vim.diagnostic.goto_next()
	end, {
		desc = "Next diagnostic (all)",
	})
	map("n", "<leader>pe", function()
		vim.diagnostic.goto_prev()
	end, {
		desc = "Previous diagnostic (all)",
	})

	-- Show diagnostic information
	map("n", "<leader>ed", vim.diagnostic.open_float, {
		desc = "Show line diagnostics",
	})
	map("n", "<leader>dl", vim.diagnostic.setloclist, {
		desc = "Show diagnostics list",
	})
	map("n", "<leader>dy", function()
		local diagnostics = vim.diagnostic.get(0, { 
			lnum = vim.fn.line(".") - 1,
		})
		if #diagnostics > 0 then
			local message = diagnostics[1].message
			vim.fn.setreg("+", message)
			vim.fn.setreg("0", message)  -- Also copy to yank register
			-- Silent copy, no notification
		else
			vim.notify("No diagnostic at cursor position", vim.log.levels.WARN)
		end
	end, {
		desc = "Copy diagnostic message to clipboard",
	})

	-- Fix delete operations to not overwrite clipboard
	map("n", "x", '"_x', {
		desc = "Delete character without affecting clipboard",
	})
	map("n", "X", '"_X', {
		desc = "Delete character backwards without affecting clipboard",
	})
	map("n", "dd", '"_dd', {
		desc = "Delete line without affecting clipboard",
	})
	map("n", "D", '"_D', {
		desc = "Delete to end of line without affecting clipboard",
	})
	map("v", "d", '"_d', {
		desc = "Delete selection without affecting clipboard",
	})
	map("n", "c", '"_c', {
		desc = "Change without affecting clipboard",
	})
	map("v", "c", '"_c', {
		desc = "Change selection without affecting clipboard",
	})
	map("n", "C", '"_C', {
		desc = "Change to end of line without affecting clipboard",
	})
	map("n", "s", '"_s', {
		desc = "Substitute without affecting clipboard",
	})
	map("n", "S", '"_S', {
		desc = "Substitute line without affecting clipboard",
	})

	-- Keep a leader mapping for intentional delete to clipboard
	map("n", "<leader>dd", "dd", {
		desc = "Delete line to clipboard",
	})
	map("v", "<leader>d", "d", {
		desc = "Delete selection to clipboard",
	})

	-- Paste without losing clipboard
	map("n", "p", '"0p', {
		desc = "Paste from yank register (preserves clipboard)",
	})
	map("n", "P", '"0P', {
		desc = "Paste before from yank register (preserves clipboard)",
	})

	-- Paste in visual mode without losing clipboard
	map("v", "p", '"0p', {
		desc = "Paste from yank register in visual mode (preserves clipboard)",
	})
	map("v", "P", '"0P', {
		desc = "Paste before from yank register in visual mode (preserves clipboard)",
	})

	-- Rust specific keymaps
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "rust",
		callback = function()
			-- Check Rust code
			map("n", "<leader>rc", function()
				vim.cmd("write")
				vim.cmd("!cargo check")
			end, {
				desc = "Cargo check",
				buffer = true,
			})

			-- Build Rust project
			map("n", "<leader>rb", function()
				vim.cmd("write")
				vim.cmd("!cargo build")
			end, {
				desc = "Cargo build",
				buffer = true,
			})

			-- Run Rust project
			map("n", "<leader>rr", function()
				vim.cmd("write")
				vim.cmd("!cargo run")
			end, {
				desc = "Cargo run",
				buffer = true,
			})

			-- Test Rust project
			map("n", "<leader>rt", function()
				vim.cmd("write")
				vim.cmd("!cargo test")
			end, {
				desc = "Cargo test",
				buffer = true,
			})

			-- Format current Rust file
			map("n", "<leader>rf", function()
				vim.cmd("write")
				vim.cmd("Format")
			end, {
				desc = "Format Rust file",
				buffer = true,
			})

			-- Note: Comment toggle (Ctrl+/ and <leader>/) is now handled by Comment.nvim plugin
			-- which works for all languages (Rust, C#, Python, Lua, etc.)
		end,
	})

	-- Java specific keymaps
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "java",
		callback = function()
			-- Compile current Java file
			map("n", "<leader>jc", function()
				local filename = vim.fn.expand("%:p")
				local classname = vim.fn.expand("%:t:r")
				local cmd = string.format("javac %s", filename)
				vim.cmd("write")
				vim.fn.system(cmd)
				if vim.v.shell_error == 0 then
					vim.notify("✓ Java compilation successful", vim.log.levels.INFO)
				else
					vim.notify("✗ Java compilation failed", vim.log.levels.ERROR)
				end
			end, {
				desc = "Compile Java file",
				buffer = true,
			})

			-- Run current Java file
			map("n", "<leader>jr", function()
				local classname = vim.fn.expand("%:t:r")
				local dir = vim.fn.expand("%:p:h")
				vim.cmd("write")
				-- Compile first
				local compile_cmd = string.format("javac %s", vim.fn.expand("%:p"))
				vim.fn.system(compile_cmd)
				if vim.v.shell_error == 0 then
					-- Then run
					local run_cmd = string.format("cd %s && java %s", dir, classname)
					vim.cmd("!" .. run_cmd)
				else
					vim.notify("✗ Compilation failed, cannot run", vim.log.levels.ERROR)
				end
			end, {
				desc = "Compile and run Java file",
				buffer = true,
			})

			-- Run with input
			map("n", "<leader>ji", function()
				local classname = vim.fn.expand("%:t:r")
				local dir = vim.fn.expand("%:p:h")
				local input_file = vim.fn.input("Input file (optional): ")
				vim.cmd("write")
				-- Compile first
				local compile_cmd = string.format("javac %s", vim.fn.expand("%:p"))
				vim.fn.system(compile_cmd)
				if vim.v.shell_error == 0 then
					-- Then run with input
					local run_cmd
					if input_file ~= "" then
						run_cmd = string.format("cd %s && java %s < %s", dir, classname, input_file)
					else
						run_cmd = string.format("cd %s && java %s", dir, classname)
					end
					vim.cmd("!" .. run_cmd)
				else
					vim.notify("✗ Compilation failed, cannot run", vim.log.levels.ERROR)
				end
			end, {
				desc = "Compile and run Java file with input",
				buffer = true,
			})

			-- Create main method template
			map("n", "<leader>jm", function()
				local lines = {
					"public static void main(String[] args) {",
					"\t",
					"}",
				}
				vim.api.nvim_put(lines, "l", true, true)
				vim.cmd("normal! 2j$")
			end, {
				desc = "Insert main method template",
				buffer = true,
			})
		end,
	})

	-- Phím Escape để thoát khỏi Neo-tree và quay lại chỗ edit
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "neo-tree",
		callback = function()
			vim.api.nvim_buf_set_keymap(0, "n", "<Esc>", ":wincmd p<CR>", {
				noremap = true,
				silent = true,
			})
		end,
	})
end

return M
