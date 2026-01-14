return {
	"olimorris/codecompanion.nvim",
	version = false,
	lazy = true,
	cmd = { "CodeCompanion" },
	keys = {
		{ "<leader>ac", ":CodeCompanion Chat<CR>", desc = "CodeCompanion Chat" },
		{ "<leader>aa", ":CodeCompanion Actions<CR>", desc = "CodeCompanion Actions" },
		{ "<leader>ai", ":CodeCompanion Inline<CR>", desc = "CodeCompanion Inline" },
		{ "<leader>c", ":CodeCompanionChat Toggle<CR>", mode = { "n", "v" }, desc = "CodeCompanion Chat Toggle" },
		{ "<leader>ag", ":CodeCompanion commit<CR>", desc = "Generate commit message" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		{ "nvim-telescope/telescope.nvim", optional = true },
		{ "stevearc/dressing.nvim", optional = true },
	},
	config = function()
		require("codecompanion").setup({
			adapters = {
				http = {
					openai = function()
						return require("codecompanion.adapters").extend("claude_sonnet_4", {
							schema = {
								model = {
									default = "claude-sonnet-4",
								},
							},
						})
					end,
				},
			},
			strategies = {
				chat = {
					adapter = {
						name = "copilot",
						model = "claude-sonnet-4",
					},
				},
				chat_gemini = {
					adapter = {
						name = "gemini",
						model = "gemini-1.5-pro",
					},
				},
			},
			prompt_library = {
				["Generate Unit Tests"] = {
					strategy = "chat",
					description = "Generate unit tests for the selected code",
					prompts = {
						{
							role = "user",
							content = "Generate unit tests for the following code:\n\n```\n#{selection}\n```",
						},
					},
				},
				["Explain Code"] = {
					strategy = "chat",
					description = "Explain the selected code",
					prompts = {
						{
							role = "user",
							content = "Explain the following code:\n\n```\n#{selection}\n```",
						},
					},
				},
				["Find Bugs"] = {
					strategy = "chat",
					description = "Find bugs in the selected code",
					prompts = {
						{
							role = "user",
							content = "Find any potential bugs in the following code:\n\n```\n#{selection}\n```",
						},
					},
				},
				["Refactor Code"] = {
					strategy = "chat",
					description = "Refactor the selected code",
					prompts = {
						{
							role = "user",
							content = "Refactor the following code to improve readability and performance. Explain the changes you made:\n\n```\n#{selection}\n```",
						},
					},
				},
				["Generate Docs"] = {
					strategy = "chat",
					description = "Generate documentation for the selected code",
					prompts = {
						{
							role = "user",
							content = "Generate documentation for the following code, including parameters, return values, and a brief description:\n\n```\n#{selection}\n```",
						},
					},
				},
				["Idiomatic Rust"] = {
					strategy = "chat",
					description = "Suggest a more idiomatic way to write the selected Rust code",
					prompts = {
						{
							role = "user",
							content = "The following Rust code works, but I'm not sure if it's idiomatic. Can you suggest a more idiomatic way to write it and explain the benefits of your suggestion?:\n\n```rust\n#{selection}\n```",
						},
					},
				},
				["Java Stream API"] = {
					strategy = "chat",
					description = "Convert the selected Java code to use the Stream API",
					prompts = {
						{
							role = "user",
							content = "Convert the following Java code to use the Stream API. Explain the changes you made:\n\n```java\n#{selection}\n```",
						},
					},
				},
				["Git Commit"] = {
					strategy = "chat",
					description = "Generate a conventional commit message",
					prompts = {
						{
							role = "user",
							content = "Based on the git diff output, generate a conventional commit message that follows the format: type(scope): description. Use types like feat, fix, docs, style, refactor, test, chore. Keep the description concise and clear.\n\nGit diff:\n```\n#{selection}\n```",
						},
					},
				},
			},
		})
		-- Popup action menu function
		local actions = {
			"Generate Unit Tests",
			"Explain Code",
			"Find Bugs",
			"Refactor Code",
			"Generate Docs",
			"Idiomatic Rust",
			"Java Stream API",
			"Git Commit",
		}

		vim.keymap.set("n", "<leader>am", function()
			vim.ui.select(actions, { prompt = "CodeCompanion Action:" }, function(choice)
				if choice then
					vim.cmd("CodeCompanion Actions " .. choice)
				end
			end)
		end, { desc = "Popup CodeCompanion Action Menu" })
	end,
}
