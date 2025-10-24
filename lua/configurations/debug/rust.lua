local M = {}

function M.find_projects()
	local cwd = vim.fn.getcwd()
	local projects = {}
	
	local cargo_files = vim.fn.glob(cwd .. "/**/Cargo.toml", true, true)
	
	for _, cargo_file in ipairs(cargo_files) do
		local project_dir = vim.fn.fnamemodify(cargo_file, ":h")
		local project_name = vim.fn.fnamemodify(project_dir, ":t")
		
		-- Read Cargo.toml to get package name and binaries
		local cargo_content = vim.fn.readfile(cargo_file)
		local package_name = project_name
		local binaries = {}
		
		local in_bin_section = false
		local current_bin = {}
		
		for _, line in ipairs(cargo_content) do
			-- Get package name
			local name_match = line:match('^name%s*=%s*"([^"]+)"')
			if name_match then
				package_name = name_match
			end
			
			-- Parse [[bin]] sections
			if line:match("^%[%[bin%]%]") then
				if current_bin.name then
					table.insert(binaries, current_bin)
				end
				current_bin = {}
				in_bin_section = true
			elseif in_bin_section then
				local bin_name = line:match('^name%s*=%s*"([^"]+)"')
				local bin_path = line:match('^path%s*=%s*"([^"]+)"')
				
				if bin_name then
					current_bin.name = bin_name
				elseif bin_path then
					current_bin.path = bin_path
				end
				
				-- Reset when we hit a new section
				if line:match("^%[") and not line:match("^%[%[bin%]%]") then
					in_bin_section = false
					if current_bin.name then
						table.insert(binaries, current_bin)
					end
					current_bin = {}
				end
			end
		end
		
		-- Add the last binary if we were in a bin section
		if current_bin.name then
			table.insert(binaries, current_bin)
		end
		
		-- If no explicit binaries found, check for default binary structure
		if #binaries == 0 then
			-- Check for src/main.rs (single binary)
			if vim.fn.filereadable(project_dir .. "/src/main.rs") == 1 then
				table.insert(binaries, {name = package_name, path = "src/main.rs"})
			end
			-- Check for common binary patterns
			local bin_patterns = {
				{name = "api", path = "src/cmd/api/main.rs"},
				{name = "worker", path = "src/cmd/worker/main.rs"},
				{name = "server", path = "src/cmd/server/main.rs"},
				{name = "client", path = "src/cmd/client/main.rs"},
			}
			
			for _, pattern in ipairs(bin_patterns) do
				if vim.fn.filereadable(project_dir .. "/" .. pattern.path) == 1 then
					table.insert(binaries, pattern)
				end
			end
		end
		
		-- Create a project entry for each binary
		if #binaries > 0 then
			for _, binary in ipairs(binaries) do
				table.insert(projects, {
					name = binary.name,
					package_name = package_name,
					dir = project_dir,
					cargo_file = cargo_file,
					binary_name = binary.name,
					binary_path = binary.path,
					display = binary.name .. " (" .. package_name .. " - " .. vim.fn.fnamemodify(project_dir, ":~:.") .. ")",
					type = "rust"
				})
			end
		else
			-- Fallback: create entry with package name
			table.insert(projects, {
				name = package_name,
				package_name = package_name,
				dir = project_dir,
				cargo_file = cargo_file,
				binary_name = package_name,
				display = package_name .. " (" .. vim.fn.fnamemodify(project_dir, ":~:.") .. ")",
				type = "rust"
			})
		end
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

local function build_rust_project_with_binary(project_dir, binary_name)
	vim.notify("🔨 Building Rust binary with debug info: " .. binary_name .. " in " .. vim.fn.fnamemodify(project_dir, ":t"), vim.log.levels.INFO)
	
	-- Ensure we build with debug symbols and disable optimizations
	local build_cmd = "cargo build --bin " .. binary_name
	local full_cmd = "cd " .. vim.fn.shellescape(project_dir) .. " && " .. build_cmd
	
	-- Use proper Windows command
	if vim.fn.has("win32") == 1 then
		full_cmd = "cd /d " .. vim.fn.shellescape(project_dir) .. " && " .. build_cmd
	end
	
	local result = vim.fn.system(full_cmd)
	local exit_code = vim.v.shell_error
	
	if exit_code == 0 then
		vim.notify("✅ Rust build successful: " .. binary_name, vim.log.levels.INFO)
		return true
	else
		local error_msg = result:match("error%[E%d+%]: (.-)%s*%->") or result:match("error: (.-)%s*%->") or result
		local short_error = error_msg and error_msg:gsub("\n.*", "") or "Build failed"
		vim.notify("❌ Rust build failed: " .. short_error, vim.log.levels.ERROR)
		
		-- Show full error in a floating window if user wants details
		vim.schedule(function()
			local choice = vim.fn.confirm("Show full build error?", "&Yes\n&No", 2)
			if choice == 1 then
				local lines = vim.split(result, '\n')
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
				
				local width = math.min(120, vim.o.columns - 4)
				local height = math.min(30, vim.o.lines - 6)
				local win = vim.api.nvim_open_win(buf, true, {
					relative = "editor",
					width = width,
					height = height,
					row = 2,
					col = 2,
					style = "minimal",
					border = "rounded",
					title = " Build Error - " .. binary_name .. " ",
					title_pos = "center",
				})
				
				vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
			end
		end)
		
		return false
	end
end

local function build_rust_project(project_dir)
	vim.notify("🔨 Building Rust project: " .. vim.fn.fnamemodify(project_dir, ":t"), vim.log.levels.INFO)
	
	local build_cmd = "cargo build"
	local full_cmd = "cd " .. vim.fn.shellescape(project_dir) .. " && " .. build_cmd
	
	-- Use proper Windows command
	if vim.fn.has("win32") == 1 then
		full_cmd = "cd /d " .. vim.fn.shellescape(project_dir) .. " && " .. build_cmd
	end
	
	local result = vim.fn.system(full_cmd)
	local exit_code = vim.v.shell_error
	
	if exit_code == 0 then
		vim.notify("✅ Rust build successful: " .. vim.fn.fnamemodify(project_dir, ":t"), vim.log.levels.INFO)
		return true
	else
		local error_msg = result:match("error%[E%d+%]: (.-)%s*%->") or result:match("error: (.-)%s*%->") or result
		local short_error = error_msg and error_msg:gsub("\n.*", "") or "Build failed"
		vim.notify("❌ Rust build failed: " .. short_error, vim.log.levels.ERROR)
		
		-- Show full error in a floating window if user wants details
		vim.schedule(function()
			local choice = vim.fn.confirm("Show full build error?", "&Yes\n&No", 2)
			if choice == 1 then
				local lines = vim.split(result, '\n')
				local buf = vim.api.nvim_create_buf(false, true)
				vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
				vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
				vim.api.nvim_buf_set_option(buf, "modifiable", false)
				
				local width = math.min(120, vim.o.columns - 4)
				local height = math.min(30, vim.o.lines - 6)
				local win = vim.api.nvim_open_win(buf, true, {
					relative = "editor",
					width = width,
					height = height,
					row = 2,
					col = 2,
					style = "minimal",
					border = "rounded",
					title = " Build Error ",
					title_pos = "center",
				})
				
				vim.api.nvim_buf_set_keymap(buf, "n", "q", ":close<CR>", { noremap = true, silent = true })
			end
		end)
		
		return false
	end
end

local function find_rust_executable(project_dir, binary_name)
	-- Try debug build first
	local debug_exe = project_dir .. "/target/debug/" .. binary_name
	
	-- Check Windows executable with .exe extension
	if vim.fn.has("win32") == 1 then
		local exe_with_extension = debug_exe .. ".exe"
		if vim.fn.filereadable(exe_with_extension) == 1 then
			return exe_with_extension
		end
	end
	
	-- Check without extension (Unix-like systems)
	if vim.fn.filereadable(debug_exe) == 1 then
		return debug_exe
	end
	
	-- Try release build as fallback
	local release_exe = project_dir .. "/target/release/" .. binary_name
	
	if vim.fn.has("win32") == 1 then
		local release_with_extension = release_exe .. ".exe"
		if vim.fn.filereadable(release_with_extension) == 1 then
			return release_with_extension
		end
	end
	
	if vim.fn.filereadable(release_exe) == 1 then
		return release_exe
	end
	
	return nil
end

function M.start_debug(project)
	vim.notify("🔍 Preparing Rust debug session for: " .. project.name, vim.log.levels.INFO)
	
	-- Check if Cargo.toml exists
	if vim.fn.filereadable(project.cargo_file) == 0 then
		vim.notify("❌ Cargo.toml not found: " .. project.cargo_file, vim.log.levels.ERROR)
		return
	end
	
	-- Build the specific binary if needed
	local build_success = false
	if project.binary_name then
		build_success = build_rust_project_with_binary(project.dir, project.binary_name)
	else
		build_success = build_rust_project(project.dir)
	end
	
	if not build_success then
		return
	end
	
	local binary_name = project.binary_name or project.name
	local executable = find_rust_executable(project.dir, binary_name)
	if not executable then
		vim.notify("❌ Executable not found for: " .. binary_name .. "\nDid the build produce a binary?", vim.log.levels.ERROR)
		
		-- Offer to try with user input
		vim.schedule(function()
			local choice = vim.fn.confirm("Executable not found. Manually specify path?", "&Yes\n&No", 2)
			if choice == 1 then
				local manual_exe = vim.fn.input("Path to executable: ", project.dir .. "/target/debug/" .. binary_name, "file")
				if manual_exe and manual_exe ~= "" and vim.fn.filereadable(manual_exe) == 1 then
					M.run_debug_session(project, manual_exe)
				end
			end
		end)
		return
	end
	
	M.run_debug_session(project, executable)
end

-- Separate function to actually run the debug session
function M.run_debug_session(project, executable)
	vim.notify("🦀 Starting Rust debug: " .. project.name, vim.log.levels.INFO)
	vim.notify("🎯 Executable: " .. vim.fn.fnamemodify(executable, ":t"), vim.log.levels.INFO)
	
	local dap = require("dap")
	
	-- Get user arguments if they want to provide any
	local args = {}
	local input_args = vim.fn.input("Arguments (optional): ")
	if input_args and input_args ~= "" then
		args = vim.split(input_args, " ", { trimempty = true })
	end
	
	dap.run({
		type = "codelldb",
		name = "Debug Rust: " .. project.name,
		request = "launch",
		program = executable,
		cwd = project.dir,
		stopOnEntry = false,
		args = args,
		runInTerminal = false,
		console = "integratedTerminal",
		-- Enhanced LLDB settings for Rust debugging
		setupCommands = {
			{
				description = "Enable pretty-printing for gdb",
				text = "-enable-pretty-printing",
				ignoreFailures = true
			},
		},
		-- CodeLLDB specific settings for Rust
		sourceLanguages = { "rust" },
		-- Better variable display format
		expressions = "native",
		-- Ensure debug info is preserved
		env = {
			RUST_BACKTRACE = "1",
		},
		-- Enhanced LLDB settings for better Rust debugging
		initCommands = {
			-- Enable automatic loading of debugging scripts
			"settings set target.load-script-from-symbol-file true",
			-- Improve inline debugging
			"settings set target.inline-breakpoint-strategy always",
			-- Better variable display
			"settings set target.prefer-dynamic-value run-target",
			-- Enable synthetic children for better container display  
			"settings set target.enable-synthetic-value true",
			-- Better frame and thread display
			"settings set frame-format 'frame #${frame.index}: ${frame.pc}{ ${module.file.basename}{`${function.name-without-args}{${function.pc-offset}}}}{ at ${line.file.basename}:${line.number}}{${function.is-optimized} [opt]}\n'",
			-- Show more detail in variable summaries
			"settings set target.max-children-count 50",
			"settings set target.max-string-summary-length 200",
		}
	})
end

function M.setup(dap, dapui)
	-- Setup CodeLLDB adapter for Rust with better error handling
	dap.adapters.codelldb = function(cb, config)
		-- Find CodeLLDB executable
		local codelldb_path = nil
		
		-- Check Mason installation first
		local mason_registry = require("mason-registry")
		if mason_registry.is_installed("codelldb") then
			local codelldb = mason_registry.get_package("codelldb")
			codelldb_path = codelldb:get_install_path() .. "/extension/adapter/codelldb.exe"
			
			-- Check if the executable exists
			if vim.fn.executable(codelldb_path) == 0 then
				-- Try alternative path structure
				codelldb_path = codelldb:get_install_path() .. "/codelldb.exe"
				if vim.fn.executable(codelldb_path) == 0 then
					codelldb_path = "codelldb" -- fallback to PATH
				end
			end
		else
			-- Try system PATH
			if vim.fn.executable("codelldb") == 1 then
				codelldb_path = "codelldb"
			else
				cb(nil, "CodeLLDB not found. Please install it via Mason or ensure it's in your PATH.")
				return
			end
		end
		
		cb({
			type = 'server',
			port = "${port}",
			executable = {
				command = codelldb_path,
				args = {"--port", "${port}"},
			}
		})
	end

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
			console = "integratedTerminal",
			sourceLanguages = { "rust" },
			expressions = "native",
		},
	}

	-- Rust-specific debug keymaps
	vim.keymap.set("n", "<leader>rda", function()
		local projects = M.find_projects()
		local api_projects = vim.tbl_filter(function(p) return p.binary_name == "api" end, projects)
		if #api_projects > 0 then
			M.start_debug(api_projects[1])
		else
			vim.notify("No API binary found in Rust projects", vim.log.levels.WARN)
		end
	end, { desc = "Rust: Debug API binary" })
	
	vim.keymap.set("n", "<leader>rdw", function()
		local projects = M.find_projects()
		local worker_projects = vim.tbl_filter(function(p) return p.binary_name == "worker" end, projects)
		if #worker_projects > 0 then
			M.start_debug(worker_projects[1])
		else
			vim.notify("No Worker binary found in Rust projects", vim.log.levels.WARN)
		end
	end, { desc = "Rust: Debug Worker binary" })

	-- Rust specific keymaps with floating windows
	vim.keymap.set("n", "<leader>rc", function()
		select_rust_project_for_command("Check", function(project)
			create_rust_float_terminal("cargo check", "Rust Check", project.dir)
		end)
	end, { desc = "Rust: Cargo check (float)" })
	
	vim.keymap.set("n", "<leader>rb", function()
		select_rust_project_for_command("Build", function(project)
			local cmd = project.binary_name and ("cargo build --bin " .. project.binary_name) or "cargo build"
			create_rust_float_terminal(cmd, "Rust Build - " .. (project.binary_name or "All"), project.dir)
		end)
	end, { desc = "Rust: Cargo build (float)" })
	
	-- Build specific binaries
	vim.keymap.set("n", "<leader>rba", function()
		select_rust_project_for_command("Build API", function(project)
			create_rust_float_terminal("cargo build --bin api", "Rust Build - API", project.dir)
		end)
	end, { desc = "Rust: Build API binary" })
	
	vim.keymap.set("n", "<leader>rbw", function()
		select_rust_project_for_command("Build Worker", function(project)
			create_rust_float_terminal("cargo build --bin worker", "Rust Build - Worker", project.dir)
		end)
	end, { desc = "Rust: Build Worker binary" })
	
	vim.keymap.set("n", "<leader>rr", function()
		select_rust_project_for_command("Run", function(project)
			local cmd = project.binary_name and ("cargo run --bin " .. project.binary_name) or "cargo run"
			create_rust_float_terminal(cmd, "Rust Run - " .. (project.binary_name or "Default"), project.dir)
		end)
	end, { desc = "Rust: Cargo run (float)" })
	
	-- Run specific binaries
	vim.keymap.set("n", "<leader>rra", function()
		select_rust_project_for_command("Run API", function(project)
			create_rust_float_terminal("cargo run --bin api", "Rust Run - API", project.dir)
		end)
	end, { desc = "Rust: Run API binary" })
	
	vim.keymap.set("n", "<leader>rrw", function()
		select_rust_project_for_command("Run Worker", function(project)
			create_rust_float_terminal("cargo run --bin worker", "Rust Run - Worker", project.dir)
		end)
	end, { desc = "Rust: Run Worker binary" })
	
	-- Debug helper keymaps
	vim.keymap.set("n", "<leader>dv", function()
		local var = vim.fn.input("Variable to inspect: ")
		if var ~= "" then
			require("dap").repl.open()
			vim.defer_fn(function()
				require("dap.repl").execute("p " .. var)
			end, 100)
		end
	end, { desc = "Debug: Inspect variable in REPL" })
	
	vim.keymap.set("n", "<leader>de", function()
		local expr = vim.fn.input("Expression to evaluate: ")
		if expr ~= "" then
			require("dap").repl.open()
			vim.defer_fn(function()
				require("dap.repl").execute("expr " .. expr)
			end, 100)
		end
	end, { desc = "Debug: Evaluate expression in REPL" })
	
	-- Debug troubleshooting commands
	vim.keymap.set("n", "<leader>da", function()
		require("dap").repl.open()
		vim.defer_fn(function()
			require("dap.repl").execute("frame variable")
			require("dap.repl").execute("bt")
		end, 100)
	end, { desc = "Debug: Show all variables & stack" })
	
	vim.keymap.set("n", "<leader>dt", function()
		require("dap").repl.open()
		vim.defer_fn(function()
			require("dap.repl").execute("type lookup String")
			require("dap.repl").execute("type lookup &str")
			require("dap.repl").execute("settings show target")
		end, 100)
	end, { desc = "Debug: Show type info & settings" })
	
	-- Date/Time debugging helpers
	vim.keymap.set("n", "<leader>dd", function()
		local var = vim.fn.input("DateTime variable to inspect: ")
		if var ~= "" then
			require("dap").repl.open()
			vim.defer_fn(function()
				-- Show the full structure first
				require("dap.repl").execute("p " .. var)
				-- Try multiple format approaches
				require("dap.repl").execute("expr " .. var .. ".to_rfc3339()")
				require("dap.repl").execute("expr " .. var .. ".format(\"%Y-%m-%d %H:%M:%S UTC\")")
				require("dap.repl").execute("expr " .. var .. ".timestamp()")
			end, 200)
		end
	end, { desc = "Debug: Inspect DateTime variable" })
	
	vim.keymap.set("n", "<leader>dn", function()
		local var = vim.fn.input("NaiveDateTime variable to inspect: ")
		if var ~= "" then
			require("dap").repl.open()
			vim.defer_fn(function()
				-- Show the structure first
				require("dap.repl").execute("p " .. var)
				-- Try different format approaches
				require("dap.repl").execute("expr " .. var .. ".format(\"%Y-%m-%d %H:%M:%S\")")
				require("dap.repl").execute("expr " .. var .. ".and_utc().to_rfc3339()")
				require("dap.repl").execute("expr " .. var .. ".and_utc().timestamp()")
			end, 200)
		end
	end, { desc = "Debug: Inspect NaiveDateTime variable" })
	
	-- Quick date conversion from internal values
	vim.keymap.set("n", "<leader>dc", function()
		require("dap").repl.open()
		vim.defer_fn(function()
			vim.notify("Chrono Internal Value Decoder", vim.log.levels.INFO)
			require("dap.repl").execute("expr // === CHRONO DECODER ===")
			require("dap.repl").execute("expr // To convert yof to human date:")
			require("dap.repl").execute("expr // 1. Find a NaiveDate field in your variables")
			require("dap.repl").execute("expr // 2. Use: <variable>.format(\"%Y-%m-%d\")")
			require("dap.repl").execute("expr // Example: payment_status_date.format(\"%Y-%m-%d %H:%M:%S UTC\")")
		end, 100)
	end, { desc = "Debug: Show chrono conversion tips" })
	
	-- Quick all-dates inspector
	vim.keymap.set("n", "<leader>dx", function()
		require("dap").repl.open()
		vim.defer_fn(function()
			-- Look for common date variable patterns and try to display them
			local common_date_vars = {
				"payment_status_date",
				"order_status_date", 
				"delivery_status_date",
				"expected_delivery_date",
				"created_at",
				"updated_at"
			}
			
			require("dap.repl").execute("expr // === ALL DATE VARIABLES ===")
			for _, date_var in ipairs(common_date_vars) do
				require("dap.repl").execute("expr " .. date_var .. ".format(\"%Y-%m-%d %H:%M:%S UTC\").unwrap_or_else(|_| \"N/A\".to_string())")
			end
		end, 300)
	end, { desc = "Debug: Show all common date variables" })
	
	-- Quick exit debug mode keymap
	vim.keymap.set("n", "<leader>dq", function()
		local dap = require("dap")
		local dapui = require("dapui")
		
		-- Stop debug session
		dap.terminate()
		-- Close debug UI
		dapui.close()
		-- Clear any debug highlights
		vim.schedule(function()
			vim.notify("🛑 Debug session ended", vim.log.levels.INFO)
		end)
	end, { desc = "Debug: Quit debug session" })
	
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
