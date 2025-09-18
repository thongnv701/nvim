local M = {}

function M.find_projects()
	local cwd = vim.fn.getcwd()
	local projects = {}

	-- Look for Python projects (various patterns)
	local python_files = vim.fn.glob(cwd .. "/**/*.py", true, true)
	local requirements_files = vim.fn.glob(cwd .. "/**/requirements.txt", true, true)
	local pyproject_files = vim.fn.glob(cwd .. "/**/pyproject.toml", true, true)
	local setup_files = vim.fn.glob(cwd .. "/**/setup.py", true, true)

	-- If we find Python files, create projects
	local project_dirs = {}
	
	-- Check for main project indicators
	for _, file in ipairs(requirements_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = true
	end
	
	for _, file in ipairs(pyproject_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = true
	end
	
	for _, file in ipairs(setup_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = true
	end
	
	-- If no project files found, use current directory if it has Python files
	if vim.tbl_count(project_dirs) == 0 and #python_files > 0 then
		project_dirs[cwd] = true
	end

	-- Create project entries
	for dir, _ in pairs(project_dirs) do
		local project_name = vim.fn.fnamemodify(dir, ":t")
		table.insert(projects, {
			name = project_name,
			dir = dir,
			display = project_name .. " (" .. vim.fn.fnamemodify(dir, ":~:.") .. ")",
			type = "python"
		})
	end

	return projects
end

-- Function to find Python executable (prefer virtual env)
local function find_python_executable(project_dir)
	-- Check for virtual environment
	local venv_paths = {
		project_dir .. "/venv/Scripts/python.exe", -- Windows venv
		project_dir .. "/venv/bin/python",         -- Unix venv
		project_dir .. "/.venv/Scripts/python.exe", -- Windows .venv
		project_dir .. "/.venv/bin/python",         -- Unix .venv
		project_dir .. "/env/Scripts/python.exe",  -- Windows env
		project_dir .. "/env/bin/python",          -- Unix env
	}

	for _, path in ipairs(venv_paths) do
		if vim.fn.executable(path) == 1 then
			return path
		end
	end

	-- Try system Python commands in order
	local system_python_commands = { "python3", "python", "py" }

	for _, cmd in ipairs(system_python_commands) do
		if vim.fn.executable(cmd) == 1 then
			return cmd
		end
	end

	-- Microsoft Store Python fallback - try using 'where' command to find it
	local function try_where_command(cmd)
		local handle = io.popen("where " .. cmd .. " 2>nul")
		if handle then
			local result = handle:read("*a")
			handle:close()
			if result and result:find("WindowsApps") and result:find("python") then
				-- Extract the first line (first path found)
				local first_path = result:match("([^\r\n]+)")
				if first_path and vim.fn.filereadable(first_path) == 1 then
					return first_path:gsub("^%s*(.-)%s*$", "%1") -- trim whitespace
				end
			end
		end
		return nil
	end

	-- Try to find Microsoft Store Python using 'where' command
	for _, cmd in ipairs({"python", "python3", "py"}) do
		local found_path = try_where_command(cmd)
		if found_path then
			return found_path
		end
	end

	-- Last resort: try common Microsoft Store paths directly
	local ms_store_paths = {
		"C:\\Users\\ADMIN\\AppData\\Local\\Microsoft\\WindowsApps\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Microsoft\\WindowsApps\\python3.exe",
	}

	for _, path in ipairs(ms_store_paths) do
		if vim.fn.filereadable(path) == 1 then
			return path
		end
	end

	return nil
end

-- Function to find main Python file
local function find_main_file(project_dir)
	local main_candidates = {
		project_dir .. "/main.py",
		project_dir .. "/app.py",
		project_dir .. "/run.py",
		project_dir .. "/__main__.py",
	}

	for _, candidate in ipairs(main_candidates) do
		if vim.fn.filereadable(candidate) == 1 then
			return candidate
		end
	end

	-- Look for any Python file
	local python_files = vim.fn.glob(project_dir .. "/*.py", true, true)
	if #python_files > 0 then
		return python_files[1]
	end

	return nil
end

function M.start_debug(project)
	local python_executable = find_python_executable(project.dir)
	if not python_executable then
		vim.notify("❌ Python executable not found for: " .. project.name, vim.log.levels.ERROR)
		return
	end

	local main_file = find_main_file(project.dir)
	if not main_file then
		main_file = vim.fn.input("Path to Python file: ", project.dir .. "/", "file")
		if not main_file or main_file == "" then
			return
		end
	end

	vim.notify("🐍 Starting Python debug: " .. project.name, vim.log.levels.INFO)

	local dap = require("dap")
	dap.run({
		type = "python",
		name = "Debug Python: " .. project.name,
		request = "launch",
		program = main_file,
		python = python_executable,
		cwd = project.dir,
		args = {},
		stopOnEntry = false,
		runInTerminal = false,
	})
end

function M.setup(dap, dapui)
	-- Setup Python adapter with better error handling
	dap.adapters.python = function(cb, config)
		if config.request == 'attach' then
			local port = (config.connect or config).port
			local host = (config.connect or config).host or '127.0.0.1'
			cb({
				type = 'server',
				port = assert(port, '`connect.port` is required for a python `attach` configuration'),
				host = host,
				options = {
					source_filetype = 'python',
				},
			})
		else
			-- Find Python executable with better detection
			local python_executable = nil
			
			-- Try to get the actual Python path
			local handle = io.popen('python -c "import sys; print(sys.executable)" 2>nul')
			if handle then
				local result = handle:read("*a")
				handle:close()
				if result and result ~= "" then
					python_executable = result:gsub("%s+", ""):gsub("\r", ""):gsub("\n", "")
				end
			end
			
			-- Fallback to command detection
			if not python_executable or python_executable == "" then
				local python_candidates = { 'python', 'python3', 'py' }
				for _, cmd in ipairs(python_candidates) do
					if vim.fn.executable(cmd) == 1 then
						python_executable = cmd
						break
					end
				end
			end
			
			if not python_executable then
				cb(nil, "Python executable not found")
				return
			end
			
			cb({
				type = 'executable',
				command = python_executable,
				args = { '-m', 'debugpy.adapter' },
				options = {
					env = vim.tbl_extend("force", vim.fn.environ(), {
						PYTHONPATH = vim.fn.getcwd()
					})
				}
			})
		end
	end

	-- Python configurations
	dap.configurations.python = {
		{
			type = 'python',
			request = 'launch',
			name = "Launch Python file",
			program = "${file}",
			python = function()
				local cwd = vim.fn.getcwd()
				local python_executable = find_python_executable(cwd)
				if python_executable then
					return python_executable
				end
				return vim.fn.input("Path to python executable: ", "python", "file")
			end,
			cwd = "${workspaceFolder}",
			args = {},
			stopOnEntry = false,
			runInTerminal = false,
		},
		{
			type = 'python',
			request = 'launch',
			name = "Launch with arguments",
			program = "${file}",
			python = function()
				local cwd = vim.fn.getcwd()
				local python_executable = find_python_executable(cwd)
				if python_executable then
					return python_executable
				end
				return vim.fn.input("Path to python executable: ", "python", "file")
			end,
			args = function()
				local input = vim.fn.input("Arguments: ")
				return vim.split(input, " ", true)
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
			runInTerminal = false,
		},
		{
			type = 'python',
			request = 'attach',
			name = 'Attach remote',
			connect = function()
				local host = vim.fn.input('Host [127.0.0.1]: ')
				host = host ~= '' and host or '127.0.0.1'
				local port = tonumber(vim.fn.input('Port [5678]: ')) or 5678
				return { host = host, port = port }
			end,
		},
	}

	-- Python specific keymaps
	vim.keymap.set("n", "<leader>pr", function()
		local file = vim.fn.expand("%:p")
		if vim.bo.filetype == "python" then
			local python_executable = find_python_executable(vim.fn.getcwd())
			if python_executable then
				vim.cmd("split | terminal " .. vim.fn.shellescape(python_executable) .. " " .. vim.fn.shellescape(file))
			else
				vim.notify("Python executable not found!", vim.log.levels.ERROR)
			end
		else
			vim.notify("Not a Python file!", vim.log.levels.WARN)
		end
	end, { desc = "Run current Python file" })

	vim.keymap.set("n", "<leader>pi", function()
		local python_executable = find_python_executable(vim.fn.getcwd())
		if python_executable then
			vim.cmd("split | terminal " .. vim.fn.shellescape(python_executable))
		else
			vim.notify("Python executable not found!", vim.log.levels.ERROR)
		end
	end, { desc = "Open Python REPL" })

end

return M
