local home = vim.fn.expand("$USERPROFILE")
local workspace_path = home .. "/.local/share/nvim/jdtls-workspace/"
local project_name = vim.fn.fnamemodify(vim.fn.getcwd(), ":p:h:t")
local workspace_dir = workspace_path .. project_name

local status, jdtls = pcall(require, "jdtls")
if not status then
	return
end

local extendedClientCapabilities = jdtls.extendedClientCapabilities
extendedClientCapabilities.resolveAdditionalTextEditsSupport = true

local capabilities = vim.lsp.protocol.make_client_capabilities()
local cmp_nvim_lsp_ok, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if cmp_nvim_lsp_ok then
	capabilities = cmp_nvim_lsp.default_capabilities(capabilities)
end

-- Resolve from Mason; fall back to stdpaths if needed
local mason_registry_ok, mason_registry = pcall(require, "mason-registry")
local function safe_get_install_path(package_name)
    if not mason_registry_ok then return nil end
    local ok, pkg = pcall(mason_registry.get_package, package_name)
    if not ok or not pkg or type(pkg.get_install_path) ~= "function" then
        return nil
    end
    return pkg:get_install_path()
end
local jdtls_install = nil
local launcher_jar = nil
local lombok_path = nil
local bundles = {}

do
    jdtls_install = safe_get_install_path("jdtls")
    if jdtls_install then
        launcher_jar = vim.fn.glob(jdtls_install .. "/plugins/org.eclipse.equinox.launcher_*.jar")
        lombok_path = jdtls_install .. "/lombok.jar"
    end

    local debug_path = safe_get_install_path("java-debug-adapter")
    if debug_path then
        local debug_bundle = vim.fn.glob(debug_path .. "/extension/server/com.microsoft.java.debug.plugin-*.jar", true)
        if debug_bundle and debug_bundle ~= "" then table.insert(bundles, debug_bundle) end
    end

    local test_path = safe_get_install_path("java-test")
    if test_path then
        local test_bundles = vim.fn.glob(test_path .. "/extension/server/*.jar", true)
        if test_bundles and test_bundles ~= "" then
            for _, b in ipairs(vim.split(test_bundles, "\n")) do
                if b ~= "" then table.insert(bundles, b) end
            end
        end
    end
end

if not launcher_jar or launcher_jar == "" then
    local mason_path = vim.fn.stdpath("data") .. "/mason/packages/jdtls"
    launcher_jar = vim.fn.glob(mason_path .. "/plugins/org.eclipse.equinox.launcher_*.jar")
    lombok_path = mason_path .. "/lombok.jar"
end

-- Prefer Mason's jdtls wrapper when available (more robust on Windows)
local mason_bin = (function()
    local base = vim.fn.stdpath("data") .. (vim.fn.has("win32") == 1 and "\\mason\\bin\\jdtls.cmd" or "/mason/bin/jdtls")
    return (vim.fn.filereadable(base) == 1) and base or nil
end)()

-- Compute root_dir using vim.fs for reliability
local root_dir = (function()
    local markers = { 'settings.gradle', 'settings.gradle.kts', 'pom.xml', 'build.gradle', 'build.gradle.kts', 'mvnw', 'gradlew', '.git' }
    local bufname = vim.api.nvim_buf_get_name(0)
    local found = vim.fs.find(markers, { upward = true, path = bufname })[1]
    return found and vim.fs.dirname(found) or (require('jdtls.setup').find_root(markers) or vim.fn.getcwd())
end)()

-- Clean stale workspace lock if present to avoid exit code 13
pcall(function()
    local lock = workspace_dir .. "/.metadata/.lock"
    if vim.fn.filereadable(lock) == 1 then vim.fn.delete(lock) end
end)

local config = {
    cmd = (function()
        if mason_bin then
            return { mason_bin }
        end
        return {
            (function()
                local java = "java"
                local java_home = vim.fn.getenv("JAVA_HOME")
                if java_home and java_home ~= vim.NIL and java_home ~= "" then
                    if vim.fn.has("win32") == 1 then
                        java = java_home .. "\\bin\\java.exe"
                    else
                        java = java_home .. "/bin/java"
                    end
                end
                return java
            end)(),
            "-Declipse.application=org.eclipse.jdt.ls.core.id1",
            "-Dosgi.bundles.defaultStartLevel=4",
            "-Declipse.product=org.eclipse.jdt.ls.core.product",
            "-Dlog.protocol=true",
            "-Dlog.level=ALL",
            "-Xmx1g",
            "--add-modules=ALL-SYSTEM",
            "--add-opens", "java.base/java.util=ALL-UNNAMED",
            "--add-opens", "java.base/java.lang=ALL-UNNAMED",
            "-javaagent:" .. (lombok_path or ""),
            "-jar", launcher_jar,
            "-configuration",
            (function()
                local base = jdtls_install or (vim.fn.stdpath("data") .. "/mason/packages/jdtls")
                local os_config = (vim.fn.has("mac") == 1) and "config_mac" or ((vim.fn.has("unix") == 1) and "config_linux" or "config_win")
                return base .. "/" .. os_config
            end)(),
            "-data", workspace_dir,
        }
    end)(),
    root_dir = root_dir,
	capabilities = capabilities,
	settings = {
		java = {
			signatureHelp = { enabled = true },
			extendedClientCapabilities = extendedClientCapabilities,
			maven = {
				downloadSources = true,
			},
			referencesCodeLens = {
				enabled = true,
			},
			references = {
				includeDecompiledSources = true,
			},
			inlayHints = {
				parameterNames = {
					enabled = "all",
				},
			},
			settings = {
				java = {
					signatureHelp = { enabled = true },
					extendedClientCapabilities = extendedClientCapabilities,
					maven = {
						downloadSources = true,
					},
					referencesCodeLens = {
						enabled = true,
					},
					references = {
						includeDecompiledSources = true,
					},
					inlayHints = {
						parameterNames = {
							enabled = "all",
						},
					},
					format = {
						enabled = true,
						settings = {
							["org.eclipse.jdt.core.formatter.tabulation.char"] = "space",
							["org.eclipse.jdt.core.formatter.indentation.size"] = "4",
							["org.eclipse.jdt.core.formatter.tabulation.size"] = "4",
							["org.eclipse.jdt.core.formatter.text_block_indentation"] = "0",
							["org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_type_header"] = "true",
							["org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_enum_declaration_header"] = "true",
							["org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_enum_constant_header"] = "true",
							["org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_annotation_declaration_header"] = "true",
							["org.eclipse.jdt.core.formatter.indent_body_declarations_compare_to_record_header"] = "true",
							["org.eclipse.jdt.core.formatter.indent_statements_compare_to_body"] = "true",
							["org.eclipse.jdt.core.formatter.indent_statements_compare_to_block"] = "true",
							["org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_switch"] = "true",
							["org.eclipse.jdt.core.formatter.indent_switchstatements_compare_to_cases"] = "true",
							["org.eclipse.jdt.core.formatter.indent_breaks_compare_to_cases"] = "true",
							["org.eclipse.jdt.core.formatter.indent_empty_lines"] = "false",
							["org.eclipse.jdt.core.formatter.brace_position_for_type_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_anonymous_type_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_constructor_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_method_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_enum_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_enum_constant"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_record_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_record_constructor"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_annotation_type_declaration"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_block"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_block_in_case"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_switch"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.brace_position_for_array_initializer"] = "end_of_line",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_type_declaration"] = "insert",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_anonymous_type_declaration"] = "insert",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_constructor_declaration"] = "insert",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_method_declaration"] = "insert",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_enum_declaration"] = "insert",
							["org.eclipse.jdt.core.formatter.insert_space_before_opening_brace_in_block"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_if"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_for"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_while"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_switch"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_catch"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_synchronized"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_method_invocation"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_opening_paren_in_method_declaration"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_opening_paren_in_method_declaration"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_closing_paren_in_method_declaration"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_opening_paren_in_method_invocation"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_closing_paren_in_method_invocation"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_assignment_operator"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_assignment_operator"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_binary_operator"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_binary_operator"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_unary_operator"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_unary_operator"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_comma_in_method_invocation_arguments"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_comma_in_method_invocation_arguments"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_comma_in_method_declaration_parameters"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_comma_in_method_declaration_parameters"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_semicolon"] = "do not insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_semicolon"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_before_colon_in_for"] = "insert",
						["org.eclipse.jdt.core.formatter.insert_space_after_colon_in_for"] = "insert",
						["org.eclipse.jdt.core.formatter.lineSplit"] = "120",
						["org.eclipse.jdt.core.formatter.continuation_indentation"] = "2",
						["org.eclipse.jdt.core.formatter.comment.line_length"] = "120",
						["org.eclipse.jdt.core.formatter.join_wrapped_lines"] = "false",
						},
					},
					contentProvider = { preferred = "fernflower" },
					import = { gradle = { enabled = true }, maven = { enabled = true } },
					implementationsCodeLens = { enabled = true },
					completion = {
						favoriteStaticMembers = {
							"org.junit.jupiter.api.Assertions.*",
							"org.junit.Assert.*",
							"org.mockito.Mockito.*",
							"org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
							"org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
						},
						importOrder = { "java", "javax", "org", "com" },
					},
					sources = {
						organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
					},
					codeGeneration = {
						toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
						useBlocks = true,
						generateComments = false,
					},
					configuration = {
						runtimes = {
							{ name = "JavaSE-17", path = "C:/Program Files/Java/jdk-17" },
							{ name = "JavaSE-21", path = "C:/Program Files/Java/jdk-21", default = true },
						},
					},
				},
			},
			contentProvider = { preferred = "fernflower" },
			import = { gradle = { enabled = true }, maven = { enabled = true } },
			implementationsCodeLens = { enabled = true },
			completion = {
				favoriteStaticMembers = {
					"org.junit.jupiter.api.Assertions.*",
					"org.junit.Assert.*",
					"org.mockito.Mockito.*",
					"org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*",
					"org.springframework.test.web.servlet.result.MockMvcResultMatchers.*",
				},
				importOrder = { "java", "javax", "org", "com" },
			},
			sources = {
				organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 },
			},
			codeGeneration = {
				toString = { template = "${object.className}{${member.name()}=${member.value}, ${otherMembers}}" },
				useBlocks = true,
				generateComments = false,
			},
			configuration = {
				runtimes = {
					{ name = "JavaSE-17", path = "C:/Program Files/Java/jdk-17" },
					{ name = "JavaSE-21", path = "C:/Program Files/Java/jdk-21", default = true },
				},
			},
		},
	},
    init_options = {
        extendedClientCapabilities = extendedClientCapabilities,
        bundles = bundles,
    },
	on_attach = function(client, bufnr)
		local opts = { buffer = bufnr, noremap = true, silent = true }

		-- LSP navigation for Java buffers
		local bufopts = { noremap = true, silent = true, buffer = bufnr }
		vim.keymap.set("n", "gd", vim.lsp.buf.definition, vim.tbl_extend("force", bufopts, { desc = "Go to definition" }))
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, vim.tbl_extend("force", bufopts, { desc = "Go to declaration" }))
		vim.keymap.set("n", "gi", vim.lsp.buf.implementation, vim.tbl_extend("force", bufopts, { desc = "Go to implementation" }))
		vim.keymap.set("n", "K", vim.lsp.buf.hover, vim.tbl_extend("force", bufopts, { desc = "Hover" }))
		vim.keymap.set("n", "<leader>rn", vim.lsp.buf.rename, vim.tbl_extend("force", bufopts, { desc = "Rename" }))
		vim.keymap.set("n", "<leader>ca", vim.lsp.buf.code_action, vim.tbl_extend("force", bufopts, { desc = "Code action" }))
		vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format({ async = true }) end, vim.tbl_extend("force", bufopts, { desc = "Format" }))

		vim.keymap.set(
			"n",
			"<leader>co",
			"<Cmd>lua require('jdtls').organize_imports()<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Organize Imports" })
		)
		vim.keymap.set(
			"n",
			"<leader>crv",
			"<Cmd>lua require('jdtls').extract_variable()<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Extract Variable" })
		)
		vim.keymap.set(
			"v",
			"<leader>crv",
			"<Esc><Cmd>lua require('jdtls').extract_variable(true)<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Extract Variable" })
		)
		vim.keymap.set(
			"n",
			"<leader>crc",
			"<Cmd>lua require('jdtls').extract_constant()<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Extract Constant" })
		)
		vim.keymap.set(
			"v",
			"<leader>crc",
			"<Esc><Cmd>lua require('jdtls').extract_constant(true)<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Extract Constant" })
		)
		vim.keymap.set(
			"v",
			"<leader>crm",
			"<Esc><Cmd>lua require('jdtls').extract_method(true)<CR>",
			vim.tbl_extend("force", opts, { desc = "Java: Extract Method" })
		)

        if client.server_capabilities.inlayHintProvider then
			vim.lsp.inlay_hint.enable(true, { bufnr = bufnr })
		end

        if bundles and #bundles > 0 then
            require("jdtls").setup_dap({ hotcodereplace = "auto" })
            pcall(require, "jdtls.dap").setup_dap_main_class_configs()
        end
	end,
}

pcall(vim.fn.mkdir, workspace_dir, "p")
if launcher_jar == nil or launcher_jar == "" then
    vim.notify("jdtls: launcher JAR not found. Ensure Mason installed 'jdtls'", vim.log.levels.ERROR)
else
    vim.notify("jdtls: starting (root=" .. config.root_dir .. ")", vim.log.levels.INFO)
    require("jdtls").start_or_attach(config)
end
