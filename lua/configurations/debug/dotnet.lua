local M = {}

function M.find_projects()
	local cwd = vim.fn.getcwd()
	local projects = {}

	local csproj_files = vim.fn.glob(cwd .. "/**/*.csproj", true, true)

	for _, csproj in ipairs(csproj_files) do
		local project_dir = vim.fn.fnamemodify(csproj, ":h")
		local project_name = vim.fn.fnamemodify(csproj, ":t:r")

		table.insert(projects, {
			name = project_name,
			dir = project_dir,
			csproj = csproj,
			display = project_name .. " (" .. vim.fn.fnamemodify(project_dir, ":~:.") .. ")",
			type = "dotnet",
		})
	end

	return projects
end

local function create_profile_selector(profiles, project_name, callback)
	local buf = vim.api.nvim_create_buf(false, true)
	local width = 50
	local height = math.min(#profiles + 4, 15)

	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local lines = { "Select Launch Profile for " .. project_name .. ":", "" }
	local profile_list = {}
	local i = 1
	for profile_name, _ in pairs(profiles) do
		table.insert(profile_list, profile_name)
		table.insert(lines, string.format("%d. %s", i, profile_name))
		i = i + 1
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
		title = " Launch Profiles ",
		title_pos = "center",
	})

	vim.api.nvim_win_set_option(win, "winhl", "Normal:Normal,FloatBorder:FloatBorder")

	for idx, profile_name in ipairs(profile_list) do
		vim.api.nvim_buf_set_keymap(buf, "n", tostring(idx), "", {
			callback = function()
				vim.api.nvim_win_close(win, true)
				callback(profile_name)
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

local function get_launch_settings(project_dir)
	local launch_settings_path = project_dir .. "/Properties/launchSettings.json"

	if vim.fn.filereadable(launch_settings_path) == 1 then
		local content = vim.fn.readfile(launch_settings_path)
		local json_str = table.concat(content, "\n")

		local ok, parsed = pcall(vim.json.decode, json_str)
		if ok and parsed.profiles then
			return parsed.profiles
		end
	end

	return nil
end

local function build_project(project_dir)
	local build_cmd = "dotnet build " .. vim.fn.shellescape(project_dir) .. " --configuration Debug"
	local result = vim.fn.system(build_cmd)
	local exit_code = vim.v.shell_error

	if exit_code == 0 then
		vim.notify("✅ Debug build successful: " .. vim.fn.fnamemodify(project_dir, ":t"), vim.log.levels.INFO)
		return true
	else
		vim.notify("❌ Debug build failed:\n" .. result, vim.log.levels.ERROR)
		return false
	end
end

local function find_dll(project_dir, project_name)
	local debug_paths = {
		project_dir .. "/bin/Debug/net8.0/" .. project_name .. ".dll",
		project_dir .. "/bin/Debug/net7.0/" .. project_name .. ".dll",
		project_dir .. "/bin/Debug/net6.0/" .. project_name .. ".dll",
	}

	for _, path in ipairs(debug_paths) do
		if vim.fn.filereadable(path) == 1 then
			return path
		end
	end

	local debug_pattern = project_dir .. "/bin/Debug/**/" .. project_name .. ".dll"
	local debug_files = vim.fn.glob(debug_pattern, true, true)

	if #debug_files > 0 then
		return debug_files[1]
	end

	return nil
end

local function open_browser(url)
	if url then
		vim.fn.system('explorer "' .. url .. '"')
		vim.notify("🌐 Browser opened: " .. url, vim.log.levels.INFO)
	end
end

local function get_browser_url(profile)
	if profile.applicationUrl then
		local urls = vim.split(profile.applicationUrl, ";")
		return urls[1]
	end
	return nil
end

local function start_debug_with_profile(project, profile_name, profile, dap)
	local dll_path = find_dll(project.dir, project.name)
	if not dll_path then
		vim.notify("❌ DLL not found for project: " .. project.name, vim.log.levels.ERROR)
		return
	end

	local env_vars = profile and profile.environmentVariables or {}
	env_vars["DEBUG_LAUNCH_PROFILE"] = profile_name
	env_vars["DEBUG_PROJECT_NAME"] = project.name

	if profile and profile.applicationUrl then
		env_vars["ASPNETCORE_URLS"] = profile.applicationUrl
	end

	vim.notify("🚀 Starting debug: " .. project.name .. " [Profile: " .. profile_name .. "]", vim.log.levels.INFO)

	dap.run({
		type = "coreclr",
		name = "Launch " .. project.name .. " (" .. profile_name .. ")",
		request = "launch",
		program = dll_path,
		cwd = project.dir,
		args = {},
		env = env_vars,
		stopAtEntry = false,
		console = "integratedTerminal",
	})

	if profile and profile.launchBrowser then
		local browser_url = get_browser_url(profile)
		if browser_url then
			vim.defer_fn(function()
				open_browser(browser_url)
			end, 3000)
		end
	end
end

function M.start_debug(project)
	if not build_project(project.dir) then
		return
	end

	local launch_settings = get_launch_settings(project.dir)
	if launch_settings then
		create_profile_selector(launch_settings, project.name, function(selected_profile)
			local profile = launch_settings[selected_profile]
			start_debug_with_profile(project, selected_profile, profile, require("dap"))
		end)
	else
		start_debug_with_profile(project, "Default", nil, require("dap"))
	end
end

function M.setup(dap, dapui)
	-- Setup .NET CoreCLR adapter
	dap.adapters.coreclr = {
		type = "executable",
		command = "netcoredbg",
		args = { "--interpreter=vscode" },
	}

	-- .NET configurations
	dap.configurations.cs = {
		{
			type = "coreclr",
			name = "Launch .NET Core (Debug)",
			request = "launch",
			program = function()
				local cwd = vim.fn.getcwd()
				local dll_files = vim.fn.glob(cwd .. "/**/bin/Debug/**/*.dll", true, true)

				if #dll_files > 0 then
					for _, dll in ipairs(dll_files) do
						local filename = vim.fn.fnamemodify(dll, ":t:r")
						local dir_name = vim.fn.fnamemodify(cwd, ":t")
						if filename == dir_name then
							return dll
						end
					end
					return dll_files[1]
				end

				return vim.fn.input("Path to DEBUG dll: ", cwd .. "/bin/Debug/", "file")
			end,
			cwd = "${workspaceFolder}",
			args = {},
			stopAtEntry = false,
			console = "integratedTerminal",
			justMyCode = false,
		},
		{
			type = "coreclr",
			name = "Attach to process",
			request = "attach",
			processId = function()
				return require("dap.utils").pick_process()
			end,
			cwd = "${workspaceFolder}",
			justMyCode = false,
		},
	}

	-- .NET specific keymaps
	vim.keymap.set("n", "<leader>db", function()
		local url = vim.fn.input("Enter URL to open: ", "https://localhost:")
		if url and url ~= "" then
			open_browser(url)
		end
	end, { desc = "Open browser with URL" })
end

return M
