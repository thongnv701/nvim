local M = {}

function M.find_projects()
	local cwd = vim.fn.getcwd()
	local projects = {}

	-- Look for Java projects (various patterns)
	local java_files = vim.fn.glob(cwd .. "/**/*.java", true, true)
	local pom_files = vim.fn.glob(cwd .. "/**/pom.xml", true, true) -- Maven
	local gradle_files = vim.fn.glob(cwd .. "/**/build.gradle", true, true) -- Gradle
	local gradle_kts_files = vim.fn.glob(cwd .. "/**/build.gradle.kts", true, true) -- Gradle Kotlin
	
	-- If we find project files, create projects
	local project_dirs = {}
	
	-- Check for Maven projects
	for _, file in ipairs(pom_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = "maven"
	end
	
	-- Check for Gradle projects
	for _, file in ipairs(gradle_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = "gradle"
	end
	
	for _, file in ipairs(gradle_kts_files) do
		local dir = vim.fn.fnamemodify(file, ":h")
		project_dirs[dir] = "gradle"
	end
	
	-- If no project files found, use current directory if it has Java files
	if vim.tbl_count(project_dirs) == 0 and #java_files > 0 then
		project_dirs[cwd] = "plain"
	end

	-- Create project entries
	for dir, build_type in pairs(project_dirs) do
		local project_name = vim.fn.fnamemodify(dir, ":t")
		table.insert(projects, {
			name = project_name,
			dir = dir,
			display = project_name .. " (" .. vim.fn.fnamemodify(dir, ":~:.") .. ") [" .. build_type .. "]",
			type = "java",
			build_type = build_type
		})
	end

	return projects
end

-- Function to find Java executable
local function find_java_executable()
	-- Try JAVA_HOME first
	local java_home = vim.fn.getenv("JAVA_HOME")
	if java_home and java_home ~= vim.NIL then
		local java_exe = java_home .. "/bin/java"
		if vim.fn.executable(java_exe) == 1 then
			return java_exe
		end
		-- Windows
		java_exe = java_home .. "\\bin\\java.exe"
		if vim.fn.executable(java_exe) == 1 then
			return java_exe
		end
	end

	-- Try system java command
	if vim.fn.executable("java") == 1 then
		return "java"
	end

	return nil
end

-- Function to find main Java file
local function find_main_file(project_dir, build_type)
	local main_candidates = {}
	
	if build_type == "maven" then
		-- Maven structure
		main_candidates = {
			project_dir .. "/src/main/java/**/Main.java",
			project_dir .. "/src/main/java/**/App.java",
			project_dir .. "/src/main/java/**/*Main.java",
			project_dir .. "/src/main/java/**/*App.java",
		}
	elseif build_type == "gradle" then
		-- Gradle structure
		main_candidates = {
			project_dir .. "/src/main/java/**/Main.java",
			project_dir .. "/src/main/java/**/App.java",
			project_dir .. "/src/main/java/**/*Main.java",
			project_dir .. "/src/main/java/**/*App.java",
		}
	else
		-- Plain Java structure
		main_candidates = {
			project_dir .. "/Main.java",
			project_dir .. "/App.java",
			project_dir .. "/*Main.java",
			project_dir .. "/*App.java",
		}
	end

	for _, pattern in ipairs(main_candidates) do
		local files = vim.fn.glob(pattern, true, true)
		if #files > 0 then
			return files[1]
		end
	end

	-- Look for any Java file with main method
	local java_files = vim.fn.glob(project_dir .. "/**/*.java", true, true)
	for _, file in ipairs(java_files) do
		local content = vim.fn.readfile(file)
		for _, line in ipairs(content) do
			if line:match("public%s+static%s+void%s+main") then
				return file
			end
		end
	end

	return nil
end

-- Function to get classpath for project
local function get_classpath(project_dir, build_type)
	if build_type == "maven" then
		return project_dir .. "/target/classes"
	elseif build_type == "gradle" then
		return project_dir .. "/build/classes/main:" .. project_dir .. "/build/classes/java/main"
	else
		return project_dir
	end
end

function M.start_debug(project)
	local java_executable = find_java_executable()
	if not java_executable then
		vim.notify("❌ Java executable not found for: " .. project.name, vim.log.levels.ERROR)
		return
	end

	local main_file = find_main_file(project.dir, project.build_type)
	if not main_file then
		main_file = vim.fn.input("Path to Java file: ", project.dir .. "/", "file")
		if not main_file or main_file == "" then
			return
		end
	end

	vim.notify("☕ Starting Java debug: " .. project.name, vim.log.levels.INFO)

	local dap = require("dap")
	local classpath = get_classpath(project.dir, project.build_type)
	local class_name = vim.fn.fnamemodify(main_file, ":t:r")
	
	dap.run({
		type = "java",
		name = "Debug Java: " .. project.name,
		request = "launch",
		mainClass = class_name,
		projectName = project.name,
		cwd = project.dir,
		classPaths = { classpath },
		args = {},
		vmArgs = "",
		stopOnEntry = false,
	})
end

function M.setup(dap, dapui)
	-- Setup Java adapter
	dap.adapters.java = function(callback)
		local mason_registry = require("mason-registry")
		local java_debug_path = mason_registry.get_package("java-debug-adapter"):get_install_path()
		local java_test_path = mason_registry.get_package("java-test"):get_install_path()
		
		callback({
			type = "server",
			host = "127.0.0.1",
			port = "${port}",
			executable = {
				command = find_java_executable() or "java",
				args = {
					"-agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=1044",
					"-Declipse.application=org.eclipse.jdt.ls.core.id1",
					"-Dosgi.bundles.defaultStartLevel=4",
					"-Declipse.product=org.eclipse.jdt.ls.core.product",
					"-jar",
					java_debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar",
				},
			},
		})
	end

	-- Java configurations
	dap.configurations.java = {
		{
			type = "java",
			request = "launch",
			name = "Launch Java file",
			mainClass = function()
				local current_file = vim.fn.expand("%:t:r")
				return vim.fn.input("Main class: ", current_file)
			end,
			projectName = function()
				return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
			end,
			cwd = "${workspaceFolder}",
			args = {},
			vmArgs = "",
			stopOnEntry = false,
		},
		{
			type = "java",
			request = "launch",
			name = "Launch with arguments",
			mainClass = function()
				local current_file = vim.fn.expand("%:t:r")
				return vim.fn.input("Main class: ", current_file)
			end,
			projectName = function()
				return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
			end,
			args = function()
				local input = vim.fn.input("Arguments: ")
				return vim.split(input, " ", true)
			end,
			vmArgs = function()
				return vim.fn.input("VM arguments: ")
			end,
			cwd = "${workspaceFolder}",
			stopOnEntry = false,
		},
		{
			type = "java",
			request = "attach",
			name = "Attach to remote",
			hostName = function()
				return vim.fn.input("Host [localhost]: ", "localhost")
			end,
			port = function()
				return tonumber(vim.fn.input("Port [5005]: ", "5005"))
			end,
		},
	}

	-- Java specific keymaps
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "java",
		callback = function()
			vim.keymap.set("n", "<leader>jd", function()
				local file = vim.fn.expand("%:p")
				local class_name = vim.fn.expand("%:t:r")
				if vim.bo.filetype == "java" then
					vim.notify("🐛 Starting Java debug for: " .. class_name, vim.log.levels.INFO)
					dap.run(dap.configurations.java[1])
				else
					vim.notify("Not a Java file!", vim.log.levels.WARN)
				end
			end, { desc = "Debug current Java file", buffer = true })
		end,
	})
end

return M

