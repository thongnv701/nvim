return {
	"rcarriga/nvim-dap-ui",
	dependencies = { "mfussenegger/nvim-dap", "nvim-neotest/nvim-nio" },
	config = function()
		local dap = require("dap")
		local dapui = require("dapui")

		dapui.setup({
			icons = { expanded = "▾", collapsed = "▸" },
			mappings = {
				expand = { "<CR>", "<2-LeftMouse>" },
				open = "o",
				remove = "d",
				edit = "e",
				repl = "r",
				toggle = "t",
			},
			layouts = {
				{
					elements = {
						{ id = "scopes", size = 0.25 },
						{ id = "breakpoints", size = 0.25 },
						{ id = "stacks", size = 0.25 },
						{ id = "watches", size = 0.25 },
					},
					size = 40,
					position = "left",
				},
				{
					elements = {
						{ id = "repl", size = 0.5 },
						{ id = "console", size = 0.5 },
					},
					size = 10,
					position = "bottom",
				},
			},
			floating = {
				max_height = 0.8,
				max_width = 0.8,
				border = "rounded",
				mappings = {
					close = { "q", "<Esc>" },
				},
			},
		})

		-- Load debug configurations
		require("configurations.debug.dotnet").setup(dap, dapui)
		require("configurations.debug.rust").setup(dap, dapui)
		require("configurations.debug.python").setup(dap, dapui)
		require("configurations.debug.java").setup(dap, dapui)
		require("configurations.debug.shared").setup(dap, dapui)

		-- Auto-open/close DAP UI
		dap.listeners.after.event_initialized["dapui_config"] = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated["dapui_config"] = function()
			dapui.close()
		end
		dap.listeners.before.event_exited["dapui_config"] = function()
			dapui.close()
		end

		-- Base keymaps
		vim.keymap.set("n", "<leader><F5>", dap.continue, { desc = "Debug: Continue" })
		vim.keymap.set("n", "<F10>", dap.step_over, { desc = "Debug: Step Over" })
		vim.keymap.set("n", "<F11>", dap.step_into, { desc = "Debug: Step Into" })
		vim.keymap.set("n", "<F12>", dap.step_out, { desc = "Debug: Step Out" })
		vim.keymap.set("n", "<leader>b", dap.toggle_breakpoint, { desc = "Debug: Toggle Breakpoint" })
		vim.keymap.set("n", "<leader>B", function()
			dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
		end, { desc = "Debug: Set Conditional Breakpoint" })
		vim.keymap.set("n", "<leader>dr", dap.repl.open, { desc = "Debug: Open REPL" })
		vim.keymap.set("n", "<leader>dl", dap.run_last, { desc = "Debug: Run Last" })
		vim.keymap.set("n", "<leader>dt", dapui.toggle, { desc = "Debug: Toggle UI" })
	end,
}
