return {
	"olimorris/codecompanion.nvim",
	version = false,
	lazy = true,
	cmd = { "CodeCompanion" },
	keys = {
		{ "<leader>ac", ":CodeCompanion Chat<CR>", desc = "CodeCompanion Chat" },
		{ "<leader>aa", ":CodeCompanion Actions<CR>", desc = "CodeCompanion Actions" },
		{ "<leader>ai", ":CodeCompanion Inline<CR>", desc = "CodeCompanion Inline" },
		{
			"<leader>c",
			mode = { "n", "v" },
			desc = "CodeCompanion Chat Toggle (with Qwen creds refresh)",
			function()
				-- Ensure Qwen OAuth credentials are restored before starting chat
				local src = "E:/acc/oauth_creds.json"
				local dest = os.getenv("USERPROFILE") .. "\\.qwen\\oauth_creds.json"

				local function file_exists(path)
					local f = io.open(path, "rb")
					if f then
						f:close()
						return true
					end
					return false
				end

				if not file_exists(src) then
					vim.notify("Qwen creds not found at " .. src, vim.log.levels.WARN)
				else
					-- Create target directory if needed
					local dest_dir = dest:match("^(.*)[/\\][^/\\]+$")
					if dest_dir then
						vim.fn.mkdir(dest_dir, "p")
					end

					local in_f = io.open(src, "rb")
					if not in_f then
						vim.notify("Failed to open Qwen creds at " .. src, vim.log.levels.ERROR)
					else
						local data = in_f:read("*a")
						in_f:close()

						local out_f, err = io.open(dest, "wb")
						if not out_f then
							vim.notify("Failed to write Qwen creds to " .. dest .. ": " .. (err or ""), vim.log.levels.ERROR)
						else
							out_f:write(data)
							out_f:close()
						end
					end
				end

				-- Now toggle CodeCompanion chat
				vim.cmd("CodeCompanionChat Toggle")
			end,
		},
		{ "<leader>ag", ":CodeCompanion commit<CR>", desc = "Generate commit message" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		{ "nvim-telescope/telescope.nvim", optional = true },
		{ "stevearc/dressing.nvim", optional = true },
	},
	config = function()
		local helpers = require("codecompanion.adapters.acp.helpers")

		local function command_exists(cmd)
			local handle = io.popen(string.format('where "%s" 2>nul', cmd))
			if handle then
				local result = handle:read("*a")
				handle:close()
				return result and result ~= ""
			end
			return false
		end

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
				acp = {
					qwen = function()
						if not command_exists("qwen") then
							vim.notify("Qwen CLI not found. Please install it first.", vim.log.levels.WARN)
							return nil
						end
						return {
							name = "qwen",
							formatted_name = "Qwen",
							type = "acp",
							roles = {
								llm = "assistant",
								user = "user",
							},
							opts = {
								vision = true,
							},
							commands = {
								default = {
									"qwen",
									"--experimental-acp",
								},
								yolo = {
									"qwen",
									"--yolo",
									"--experimental-acp",
								},
							},
							defaults = {
								auth_method = "qwen-oauth", -- "qwen-oauth"|"qwen-api-key"|"dashscope"
								mcpServers = {},
								timeout = 200000, -- 200 seconds for OAuth flows
							},
							env = {},
							parameters = {
								protocolVersion = 1,
								clientCapabilities = {
									fs = { readTextFile = true, writeTextFile = true },
								},
								clientInfo = {
									name = "CodeCompanion.nvim",
									version = "1.0.0",
								},
							},
							handlers = {
								setup = function(self)
									return true
								end,
								form_messages = function(self, messages, capabilities)
									return helpers.form_messages(self, messages, capabilities)
								end,
								on_exit = function(self, code) end,
							},
						}
					end,
				},
			},
			strategies = {
				--[[chat = {
					adapter = {
						name = "copilot",
						model = "claude-sonnet-4",
					},
				}, ]]
				--
				chat = {
					adapter = "qwen", -- Use Qwen as default chat adapter
					tools = {
						duckduckgo = {
							description = "Search the web using DuckDuckGo",
							callback = {
								name = "duckduckgo_search",
								cmds = {
									function(self, args, input)
										local query = args.query
										if not query or query == "" then
											return { status = "error", data = "Query is required" }
										end

										local cmd = {
											"curl",
											"-s",
											"https://api.duckduckgo.com/?q="
												.. vim.fn.shellescape(query)
												.. "&format=json",
										}

										local result = vim.system(cmd, { text = true }):wait()

										if result.code ~= 0 then
											return { status = "error", data = "Failed to fetch results from DuckDuckGo" }
										end

										local response_data = vim.json.decode(result.stdout)

										if not response_data then
											return { status = "error", data = "Invalid response from DuckDuckGo" }
										end

										local results = {}
										local max_results = 5

										if response_data.RelatedTopics and #response_data.RelatedTopics > 0 then
											for i, topic in ipairs(response_data.RelatedTopics) do
												if i > max_results then
													break
												end
												if topic.Text and topic.FirstURL then
													table.insert(
														results,
														string.format(
															"[%s] %s - %s",
															topic.FirstURL,
															topic.Text:sub(1, 100),
															topic.FirstURL
														)
													)
												end
											end
										end

										if response_data.AbstractText and response_data.AbstractText ~= "" then
											table.insert(
												results,
												1,
												string.format(
													"**Direct Answer**: %s\nSource: %s",
													response_data.AbstractText,
													response_data.AbstractURL or "DuckDuckGo"
												)
											)
										end

										if #results == 0 then
											return { status = "error", data = "No results found for: " .. query }
										end

										return {
											status = "success",
											data = "Search results for '" .. query .. "':\n\n" .. table.concat(
												results,
												"\n\n"
											),
										}
									end,
								},
								schema = {
									type = "function",
									["function"] = {
										name = "duckduckgo_search",
										description = "Search the web using DuckDuckGo. Returns direct answers, abstracts, and related topics. Does not require an API key.",
										parameters = {
											type = "object",
											properties = {
												query = {
													type = "string",
													description = "The search query to look up on DuckDuckGo",
												},
											},
											required = { "query" },
											additionalProperties = false,
										},
										strict = true,
									},
								},
								system_prompt = [[## DuckDuckGo Search Tool
									You have access to a DuckDuckGo search tool that searches the web for information. The tool provides:
									- Direct answers to common questions
									- Abstracts and summaries
									- Related topics and links

									Use this tool when you need current information not in your training data, to verify facts, or to find specific resources. The tool requires only a search query.]],
								handlers = {
									setup = function(self, tools)
										return true
									end,
									on_exit = function(self, tools) end,
								},
								output = {
									success = function(self, tools, cmd, stdout)
										local chat = tools.chat
										return chat:add_tool_output(self, tostring(stdout[1]))
									end,
									error = function(self, tools, cmd, stderr)
										local chat = tools.chat
										return chat:add_tool_output(
											self,
											"DuckDuckGo search failed: " .. tostring(stderr[1])
										)
									end,
								},
							},
						},
					},
					opts = {
						system_prompts = (function()
							local prompts = {}
							-- Try to load a markdown prompt from the workspace.
							-- Primary path: <workspace>/vscode_chatmode/beastmode.md
							-- Secondary (backup) path: <workspace>/.vscode/vscode_chatmode/beastmode.md
							local cwd = vim.fn.getcwd()
							local md_paths = {
								cwd .. "/lua/plugins/codecompanion-chatmode/senior.md",
							}
							local found
							for _, md_path in ipairs(md_paths) do
								local f = io.open(md_path, "r")
								if f then
									local content = f:read("*a")
									f:close()
									table.insert(prompts, {
										name = "senior",
										description = "Senior Mode (from " .. md_path .. ")",
										system_prompt = content,
									})
									found = true
									break
								end
							end
							if found then
								vim.notify("Loaded Senior Mode prompt from workspace.", vim.log.levels.INFO)
								return prompts
							end
						end)(),
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
