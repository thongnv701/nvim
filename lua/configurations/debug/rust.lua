local M = {}

function M.find_projects()
	local cwd = vim.fn.getcwd()
	local projects = {}
	
	local cargo_files = vim.fn.glob(cwd .. "/**/Cargo.toml", true, true)
	
	for _, cargo_file in ipairs(cargo_files) do
		local project_dir = vim.fn.fnamemodify(cargo_file, ":h")
		local project_name = vim.fn.fnamemodify(project_dir, ":t")
		
		-- Read Cargo.toml to get package name
		local cargo_content = vim.fn.readfile(cargo_file)
		local package_name = project_name
		
		for _, line in ipairs(cargo_content) do
			local name_match = line:match('^name%s*=%s*"([^"]+)"')
			if name_match then
				package_name = name_match
				break
			end
		end
		
		table.insert(projects, {
			name = package_name,
			dir = project_dir,
			cargo_file = cargo_file,
			display = package_name .. " (" .. vim.fn.fnamemodify(project_dir, ":~:.") .. ")",
			type = "rust"
		})
	end
	
	return projects
end

-- Function để tạo floating terminal cho Rust commands (Simple version)
local function create_rust_float_terminal(cmd, title, project_dir)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.floor(vim.o.lines * 0.8)
	
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	
	-- Tạo buffer terminal trống
	local buf = vim.api.nvim_create_buf(false, true)
	
	-- Tạo floating window
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " " .. title .. " ",
		title_pos = "center",
	})
	
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")
	
	-- Chạy terminal command
	local full_cmd = project_dir and ("cd " .. vim.fn.shellescape(project_dir) .. " && " .. cmd) or cmd
	
	local job_id = vim.fn.termopen(full_cmd, {
		on_exit = function(_, exit_code)
			vim.schedule(function()
				if exit_code == 0 then
					vim.notify("✅ " .. title .. " completed successfully", vim.log.levels.INFO)
				else
					vim.notify("❌ " .. title .. " failed with exit code: " .. exit_code, vim.log.levels.ERROR)
				end
			end)
		end
	})
	
	-- Function để đóng window
	local function close_window()
		if job_id and job_id > 0 then
			vim.fn.jobstop(job_id)
		end
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end
	
	-- Keymaps
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		callback = close_window,
		noremap = true,
		silent = true,
	})
	
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
		callback = close_window,
		noremap = true,
		silent = true,
	})
	
	-- Terminal navigation
	vim.api.nvim_buf_set_keymap(buf, "t", "<C-\\><C-n>", "<C-\\><C-n>", {
		noremap = true,
		silent = true,
	})
	
	-- Start in insert mode
	vim.cmd("startinsert")
	
	-- Show info in command line
	vim.schedule(function()
		vim.api.nvim_echo({
			{"Running: ", "Normal"},
			{cmd, "String"},
			{" in ", "Normal"},
			{project_dir or vim.fn.getcwd(), "Directory"}
		}, false, {})
	end)
end

-- Function để chọn Rust project cho commands
local function select_rust_project_for_command(command_name, command_func)
	local projects = M.find_projects()
	
	if #projects == 0 then
		vim.notify("No Rust projects found!", vim.log.levels.ERROR)
		return
	end
	
	if #projects == 1 then
		command_func(projects[1])
		return
	end
	
	-- Multiple projects - create selector
	local buf = vim.api.nvim_create_buf(false, true)
	local width = 60
	local height = math.min(#projects + 4, 20)
	
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)
	
	local lines = { "Select Rust Project for " .. command_name .. ":", "" }
	for i, project in ipairs(projects) do
		table.insert(lines, string.format("%d. 🦀 %s", i, project.display))
	end
	table.insert(lines, "")
	table.insert(lines, "Press number or 'q' to cancel")
	
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Rust Projects ",
		title_pos = "center",
	})
	
	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")
	
	for i, project in ipairs(projects) do
		vim.api.nvim_buf_set_keymap(buf, "n", tostring(i), "", {
			callback = function()
				vim.api.nvim_win_close(win, true)
				command_func(project)
			end,
			noremap = true,
			silent = true,
		})
	end
	
	local function close_window()
		vim.api.nvim_win_close(win, true)
	end
	
	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		callback = close_window,
		noremap = true,
		silent = true,
	})
	
	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
		callback = close_window,
		noremap = true,
		silent = true,
	})
end

local function build_rust_project(project_dir)
	local build_cmd = "cargo build"
	local result = vim.fn.system("cd " .. vim.fn.shellescape(project_dir) .. " && " .. build_cmd)
	local exit_code = vim.v.shell_error
	
	if exit_code == 0 then
		vim.notify("✅ Rust build successful: " .. vim.fn.fnamemodify(project_dir, ":t"), vim.log.levels.INFO)
		return true
	else
		vim.notify("❌ Rust build failed:\n" .. result, vim.log.levels.ERROR)
		return false
	end
end

local function find_rust_executable(project_dir, package_name)
	local debug_exe = project_dir .. "/target/debug/" .. package_name
	if vim.fn.executable(debug_exe) == 1 then
		return debug_exe
	end
	
	if vim.fn.has("win32") == 1 then
		debug_exe = debug_exe .. ".exe"
		if vim.fn.executable(debug_exe) == 1 then
			return debug_exe
		end
	end
	
	return nil
end

function M.start_debug(project)
	if not build_rust_project(project.dir) then
		return
	end
	
	local executable = find_rust_executable(project.dir, project.name)
	if not executable then
		vim.notify("❌ Executable not found for: " .. project.name, vim.log.levels.ERROR)
		return
	end
	
	vim.notify("🦀 Starting Rust debug: " .. project.name, vim.log.levels.INFO)
	
	local dap = require("dap")
	dap.run({
		type = "codelldb",
		name = "Debug Rust: " .. project.name,
		request = "launch",
		program = executable,
		cwd = project.dir,
		stopOnEntry = false,
		args = {},
		runInTerminal = false,
	})
end

function M.setup(dap, dapui)
	-- Setup CodeLLDB adapter for Rust
	dap.adapters.codelldb = {
		type = 'server',
		port = "${port}",
		executable = {
			command = 'codelldb',
			args = {"--port", "${port}"},
		}
	}

	-- Rust configurations
	dap.configurations.rust = {
		{
			type = "codelldb",
			name = "Debug Rust",
			request = "launch",
			program = function()
				local cwd = vim.fn.getcwd()
				local cargo_file = cwd .. "/Cargo.toml"
				
				if vim.fn.filereadable(cargo_file) == 0 then
					return vim.fn.input("Path to executable: ", cwd .. "/target/debug/", "file")
				end
				
				local cargo_content = vim.fn.readfile(cargo_file)
				local package_name = vim.fn.fnamemodify(cwd, ":t")
				
				for _, line in ipairs(cargo_content) do
					local name_match = line:match('^name%s*=%s*"([^"]+)"')
					if name_match then
						package_name = name_match
						break
					end
				end
				
				local exe_path = cwd .. "/target/debug/" .. package_name
				if vim.fn.has("win32") == 1 then
					exe_path = exe_path .. ".exe"
				end
				
				if vim.fn.executable(exe_path) == 1 then
					return exe_path
				end
				
				return vim.fn.input("Path to executable: ", cwd .. "/target/debug/", "file")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			args = {},
			runInTerminal = false,
		},
	}

	-- Rust specific keymaps với floating windows
	vim.keymap.set("n", "<leader>rc", function()
		select_rust_project_for_command("Check", function(project)
			create_rust_float_terminal("cargo check", "Rust Check", project.dir)
		end)
	end, { desc = "Rust: Cargo check (float)" })
	
	vim.keymap.set("n", "<leader>rb", function()
		select_rust_project_for_command("Build", function(project)
			create_rust_float_terminal("cargo build", "Rust Build", project.dir)
		end)
	end, { desc = "Rust: Cargo build (float)" })
	
	vim.keymap.set("n", "<leader>rr", function()
		select_rust_project_for_command("Run", function(project)
			create_rust_float_terminal("cargo run", "Rust Run", project.dir)
		end)
	end, { desc = "Rust: Cargo run (float)" })
	
	vim.keymap.set("n", "<leader>rt", function()
		select_rust_project_for_command("Test", function(project)
			create_rust_float_terminal("cargo test", "Rust Test", project.dir)
		end)
	end, { desc = "Rust: Cargo test (float)" })
	
	-- Thêm một số commands khác
	vim.keymap.set("n", "<leader>rR", function()
		select_rust_project_for_command("Release Build", function(project)
			create_rust_float_terminal("cargo build --release", "Rust Release Build", project.dir)
		end)
	end, { desc = "Rust: Cargo build --release (float)" })
	
	vim.keymap.set("n", "<leader>rC", function()
		select_rust_project_for_command("Clean", function(project)
			create_rust_float_terminal("cargo clean", "Rust Clean", project.dir)
		end)
	end, { desc = "Rust: Cargo clean (float)" })
	
	vim.keymap.set("n", "<leader>rd", function()
		select_rust_project_for_command("Doc", function(project)
			create_rust_float_terminal("cargo doc --open", "Rust Doc", project.dir)
		end)
	end, { desc = "Rust: Cargo doc (float)" })
	
	vim.keymap.set("n", "<leader>rf", function()
		select_rust_project_for_command("Format", function(project)
			create_rust_float_terminal("cargo fmt", "Rust Format", project.dir)
		end)
	end, { desc = "Rust: Cargo fmt (float)" })
	
	vim.keymap.set("n", "<leader>rl", function()
		select_rust_project_for_command("Clippy", function(project)
			create_rust_float_terminal("cargo clippy", "Rust Clippy", project.dir)
		end)
	end, { desc = "Rust: Cargo clippy (float)" })
end

return M
