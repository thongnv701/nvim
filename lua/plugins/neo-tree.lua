return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = { "nvim-lua/plenary.nvim", "nvim-tree/nvim-web-devicons", "MunifTanjim/nui.nvim" },
	config = function()
		-- Helper to detect malformed paths (e.g., multiple drive letters)
		local function is_valid_path(path)
			if not path or path == "" then
				return false
			end
			-- Check for malformed Windows paths with multiple drive letters
			-- Pattern: starts with drive letter, then has another drive letter somewhere
			if path:match("^[A-Za-z]:[\\/].*[A-Za-z]:[\\/]") then
				return false
			end
			return true
		end

		-- Normalize path helper
		local function normalize_path(path)
			if not path or path == "" then
				return nil
			end
			-- Use fnamemodify to get absolute path
			local normalized = vim.fn.fnamemodify(path, ":p")
			-- Remove trailing separator
			return normalized:gsub("[\\/]+$", "")
		end

		-- Wrap neo-tree operations to catch errors
		local ok, neo_tree = pcall(require, "neo-tree")
		if not ok then
			vim.notify("neo-tree: Failed to load", vim.log.levels.ERROR)
			return
		end

		-- Ensure CWD is valid before neo-tree initializes
		vim.schedule(function()
			local cwd = vim.fn.getcwd()
			if cwd and cwd ~= "" then
				if not is_valid_path(cwd) then
					-- CWD is malformed, change to a safe directory
					local safe_dir = vim.fn.expand("$HOME") or vim.fn.expand("$USERPROFILE") or vim.fn.expand("~")
					if safe_dir and safe_dir ~= "" and is_valid_path(safe_dir) then
						pcall(function()
							vim.cmd("cd " .. vim.fn.fnameescape(normalize_path(safe_dir) or safe_dir))
						end)
					end
				end
			end
		end)

		-- Wrap setup in pcall to catch initialization errors
		local setup_ok, setup_err = pcall(function()
			neo_tree.setup({
			close_if_last_window = true,
			enable_git_status = true,
			enable_diagnostics = true,
			filesystem = {
				-- Explicitly set root to prevent path resolution issues
				-- This ensures neo-tree always uses a valid, normalized path
				root = function()
					local cwd = vim.fn.getcwd()
					if cwd and cwd ~= "" and is_valid_path(cwd) then
						local normalized = normalize_path(cwd)
						if normalized then
							return normalized
						end
					end
					-- Fallback: use the current buffer's directory if CWD is invalid
					local bufname = vim.api.nvim_buf_get_name(0)
					if bufname and bufname ~= "" and is_valid_path(bufname) then
						local dir = vim.fn.fnamemodify(bufname, ":p:h")
						if dir and is_valid_path(dir) then
							return normalize_path(dir) or dir
						end
					end
					-- Final fallback: use home directory
					local home = vim.fn.expand("$HOME") or vim.fn.expand("$USERPROFILE") or vim.fn.expand("~")
					if home and home ~= "" and is_valid_path(home) then
						return normalize_path(home) or home
					end
					-- Last resort: return nil to let neo-tree use its default
					return nil
				end,
				filtered_items = {
					visible = true, -- This is what toggles the visibility
					hide_dotfiles = false, -- Show dotfiles (.env, .gitignore, etc.)
					hide_gitignored = false, -- Show gitignored files  
					hide_hidden = false, -- Show hidden files (Windows hidden attribute)
					hide_by_name = {
						-- Add any files you want to keep hidden
						-- ".DS_Store",
						-- "thumbs.db"
					},
					never_show = {
						-- Files that should never be shown
						-- ".git",
					},
					-- Filter out malformed paths to prevent errors
					custom = function(item, context)
						if item and item.path then
							local path = item.path
							-- Check for malformed paths (multiple drive letters)
							if not is_valid_path(path) then
								return true -- Hide invalid paths
							end
							-- Also hide jdtls workspace directories to avoid conflicts
							if path:match("jdtls%-workspace") then
								return true
							end
						end
						return false -- Show valid paths
					end,
				},
				-- Enable follow_current_file with path validation to work like VSCode explorer
				follow_current_file = {
					enabled = true, -- Enable to show tree view like VSCode
					leave_dirs_open = true, -- Keep directories open to show full tree structure
				},
				-- Enable hijack_netrw_behavior but with path validation
				-- This makes neo-tree work like VSCode's file explorer
				hijack_netrw_behavior = "open_current",
				use_libuv_file_watcher = true,
				-- Add Windows-specific path handling
				bind_to_cwd = false,
				cwd_target = {
					sidebar = "tab",
					current = "window"
				},
			},
			window = {
				width = 50,
				-- Add position to avoid conflicts
				position = "left",
			},
			-- Add error handling for malformed paths
			event_handlers = {
				{
					event = "neo_tree_buffer_enter",
					handler = function(args)
						-- Ensure proper current directory with validation
						pcall(function()
							local cwd = vim.fn.getcwd()
							if cwd and cwd ~= "" and is_valid_path(cwd) then
								local normalized = normalize_path(cwd)
								if normalized then
									vim.cmd("cd " .. vim.fn.fnameescape(normalized))
								end
							end
						end)
					end,
				},
				{
					event = "file_opened",
					handler = function(args)
						-- Validate file paths when files are opened
						pcall(function()
							if args and args.path and not is_valid_path(args.path) then
								vim.notify("neo-tree: Skipping invalid path: " .. args.path, vim.log.levels.WARN)
							end
						end)
					end,
				},
				{
					event = "neo_tree_error",
					handler = function(args)
						-- Catch and suppress errors related to malformed paths
						if args and args.error then
							local error_msg = tostring(args.error)
							if error_msg:match("bad argument.*insert") or error_msg:match("table index is nil") then
								-- Suppress these specific errors related to malformed paths
								return true
							end
						end
					end,
				},
			},
			})
		end)

		if not setup_ok then
			local error_str = tostring(setup_err)
			-- Check if this is a path-related error we should suppress
			if error_str:match("bad argument.*insert.*table expected") or
			   error_str:match("table index is nil") or
			   error_str:match("Error creating item for.*[A-Za-z]:[\\/].*[A-Za-z]:[\\/]") then
				vim.notify("neo-tree: Suppressed path error during setup", vim.log.levels.WARN)
			else
				vim.notify("neo-tree: Setup error: " .. error_str, vim.log.levels.ERROR)
			end
		end

		-- Wrapper function to ensure valid CWD before opening neo-tree
		local function safe_neo_tree_command(cmd)
			return function()
				-- Validate and fix CWD before opening neo-tree
				pcall(function()
					local cwd = vim.fn.getcwd()
					if cwd and cwd ~= "" then
						if not is_valid_path(cwd) then
							-- CWD is malformed, try to fix it
							local bufname = vim.api.nvim_buf_get_name(0)
							if bufname and bufname ~= "" and is_valid_path(bufname) then
								local dir = vim.fn.fnamemodify(bufname, ":p:h")
								if dir and is_valid_path(dir) then
									vim.cmd("cd " .. vim.fn.fnameescape(normalize_path(dir) or dir))
								end
							else
								-- Fallback to home directory
								local safe_dir = vim.fn.expand("$HOME") or vim.fn.expand("$USERPROFILE") or vim.fn.expand("~")
								if safe_dir and safe_dir ~= "" and is_valid_path(safe_dir) then
									vim.cmd("cd " .. vim.fn.fnameescape(normalize_path(safe_dir) or safe_dir))
								end
							end
						end
					end
				end)
				-- Now execute the neo-tree command
				vim.cmd(cmd)
			end
		end

		vim.keymap.set("n", "<M-1>", safe_neo_tree_command("Neotree toggle"), {
			desc = "Toggle Explorer",
			silent = true,
		})
		vim.keymap.set("n", "<leader>ef", safe_neo_tree_command("Neotree focus"), {
			desc = "Focus Explorer",
			silent = true,
		})

		-- Generic function to validate and fix CWD for any file type
		-- This prevents malformed paths from being passed to neo-tree
		local function validate_and_fix_cwd(notify_user)
			pcall(function()
				local cwd = vim.fn.getcwd()
				-- Check if CWD is malformed
				if cwd and cwd ~= "" and not is_valid_path(cwd) then
					-- Try to fix CWD using the current buffer's directory
					local bufname = vim.api.nvim_buf_get_name(0)
					if bufname and bufname ~= "" and is_valid_path(bufname) then
						local dir = vim.fn.fnamemodify(bufname, ":p:h")
						if dir and is_valid_path(dir) then
							local normalized = normalize_path(dir)
							if normalized then
								vim.cmd("cd " .. vim.fn.fnameescape(normalized))
								if notify_user then
									vim.notify("neo-tree: Fixed malformed CWD to: " .. normalized, vim.log.levels.INFO)
								end
								return
							end
						end
					end
					-- Fallback to home directory
					local home = vim.fn.expand("$HOME") or vim.fn.expand("$USERPROFILE") or vim.fn.expand("~")
					if home and home ~= "" and is_valid_path(home) then
						local normalized = normalize_path(home)
						if normalized then
							vim.cmd("cd " .. vim.fn.fnameescape(normalized))
							if notify_user then
								vim.notify("neo-tree: Fixed malformed CWD to home directory", vim.log.levels.INFO)
							end
						end
					end
				elseif cwd and cwd ~= "" then
					-- Even if CWD is valid, normalize it to prevent future issues
					local normalized = normalize_path(cwd)
					if normalized and normalized ~= cwd then
						vim.cmd("cd " .. vim.fn.fnameescape(normalized))
					end
				end
			end)
		end

		-- Validate CWD when any file is opened (works for Java, Rust, C#, and all other file types)
		vim.api.nvim_create_autocmd("BufEnter", {
			callback = function()
				-- Only validate if we have a real file (not empty buffer)
				local bufname = vim.api.nvim_buf_get_name(0)
				if bufname and bufname ~= "" then
					vim.schedule(function()
						-- Silently fix CWD without notification to avoid spam
						validate_and_fix_cwd(false)
					end)
				end
			end,
		})

		-- Also validate when filetype is set (for languages that set filetype after BufEnter)
		vim.api.nvim_create_autocmd("FileType", {
			callback = function()
				vim.schedule(function()
					-- Only notify on first fix to avoid spam
					validate_and_fix_cwd(true)
				end)
			end,
		})
	end,
}
