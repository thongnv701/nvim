local M = {}

-- Function to find Python executable with robust Windows support
local function find_python_executable(project_dir)
	-- Check for virtual environment first
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

	-- Try to find Python using actual execution test (better for Windows)
	local function test_python_command(cmd)
		local handle = io.popen(cmd .. ' --version 2>nul')
		if handle then
			local result = handle:read("*a")
			handle:close()
			if result and result:find("Python") then
				return cmd
			end
		end
		return nil
	end

	-- Test Python commands in order
	local python_candidates = { "python", "python3", "py" }
	for _, cmd in ipairs(python_candidates) do
		local working_cmd = test_python_command(cmd)
		if working_cmd then
			return working_cmd
		end
	end

	-- Try common Windows paths directly
	local windows_python_paths = {
		"C:\\Python39\\python.exe",
		"C:\\Python310\\python.exe", 
		"C:\\Python311\\python.exe",
		"C:\\Python312\\python.exe",
		"C:\\Python313\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Microsoft\\WindowsApps\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Python\\Python39\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Python\\Python310\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Python\\Python311\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Python\\Python312\\python.exe",
		"C:\\Users\\ADMIN\\AppData\\Local\\Programs\\Python\\Python313\\python.exe",
	}

	for _, path in ipairs(windows_python_paths) do
		if vim.fn.filereadable(path) == 1 then
			return path
		end
	end

	return nil
end

-- Custom floating window cho project selection
function M.create_project_selector(projects, callback)
	local buf = vim.api.nvim_create_buf(false, true)
	local width = 60
	local height = math.min(#projects + 4, 20)

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local lines = { "Select Project to Debug:", "" }
	for i, project in ipairs(projects) do
		local icon = project.type == "rust" and "🦀" or (project.type == "python" and "🐍" or "🔷")
		table.insert(lines, string.format("%d. %s %s", i, icon, project.display))
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
		title = " Projects (.NET & Rust & Python) ",
		title_pos = "center",
	})

	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")

	for i, project in ipairs(projects) do
		vim.api.nvim_buf_set_keymap(buf, "n", tostring(i), "", {
			callback = function()
				vim.api.nvim_win_close(win, true)
				callback(project)
			end,
			noremap = true,
			silent = true,
		})
	end

	vim.api.nvim_buf_set_keymap(buf, "n", "q", "", {
		callback = function()
			vim.api.nvim_win_close(win, true)
		end,
		noremap = true,
		silent = true,
	})

	vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
		callback = function()
			vim.api.nvim_win_close(win, true)
		end,
		noremap = true,
		silent = true,
	})
end

function M.setup(dap, dapui)
	-- Main F5 debug function
	local function debug_project()
		local dotnet = require("configurations.debug.dotnet")
		local rust = require("configurations.debug.rust")
		local python = require("configurations.debug.python")

		local dotnet_projects = dotnet.find_projects() or {}
		local rust_projects = rust.find_projects() or {}
		local python_projects = python.find_projects() or {}

		for _, project in ipairs(rust_projects) do
			project.type = "rust"
		end
		for _, project in ipairs(dotnet_projects) do
			project.type = "dotnet"
		end
		for _, project in ipairs(python_projects) do
			project.type = "python"
		end

		local all_projects = {}
		vim.list_extend(all_projects, rust_projects)
		vim.list_extend(all_projects, dotnet_projects)
		vim.list_extend(all_projects, python_projects)

		if #all_projects == 0 then
			vim.notify("No .NET, Rust, or Python projects found!", vim.log.levels.ERROR)
			return
		end

		if #all_projects == 1 then
			local project = all_projects[1]
			if project.type == "rust" then
				rust.start_debug(project)
			elseif project.type == "python" then
				python.start_debug(project)
			else
				dotnet.start_debug(project)
			end
		else
			M.create_project_selector(all_projects, function(selected_project)
				if selected_project.type == "rust" then
					rust.start_debug(selected_project)
				elseif selected_project.type == "python" then
					python.start_debug(selected_project)
				else
					dotnet.start_debug(selected_project)
				end
			end)
		end
	end

	-- F5: Debug current file directly
	local function debug_current_file()
		local filetype = vim.bo.filetype
		local current_file = vim.fn.expand("%:p")
		
		if current_file == "" then
			vim.notify("No file is open!", vim.log.levels.WARN)
			return
		end
		
		if filetype == "python" then
			-- Use standard DAP configuration for Python files
			local dap = require("dap")
			vim.notify("🐍 Starting Python debug for: " .. vim.fn.fnamemodify(current_file, ":t"), vim.log.levels.INFO)
			
			-- Use the first Python configuration from our DAP setup
			dap.run(dap.configurations.python[1])
		elseif filetype == "rust" then
			-- For Rust, fall back to project detection since it needs cargo
			local rust = require("configurations.debug.rust")
			local rust_projects = rust.find_projects() or {}
			if #rust_projects > 0 then
				rust.start_debug(rust_projects[1])
			else
				vim.notify("No Rust project found!", vim.log.levels.ERROR)
			end
		elseif filetype == "cs" or filetype == "csharp" then
			-- For C#, fall back to project detection since it needs solution/project files
			local dotnet = require("configurations.debug.dotnet")
			local dotnet_projects = dotnet.find_projects() or {}
			if #dotnet_projects > 0 then
				dotnet.start_debug(dotnet_projects[1])
			else
				vim.notify("No .NET project found!", vim.log.levels.ERROR)
			end
		else
			-- Fall back to the original project selector for unsupported file types
			debug_project()
		end
	end
	
	vim.keymap.set("n", "<F5>", debug_current_file, { desc = "Debug: Current File" })
	
	-- Add Shift+F5 for the original project selector behavior
	vim.keymap.set("n", "<S-F5>", debug_project, { desc = "Debug: Select Project (.NET/Rust/Python)" })
end

return M
