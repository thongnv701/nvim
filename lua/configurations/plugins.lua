local M = {}
function M.setup()
	local plugin_configs = {}
	local plugin_path = vim.fn.stdpath("config") .. "/lua/plugins"
	local plugin_files = vim.fn.glob(plugin_path .. "/*.lua", false, true)
	for _, file in ipairs(plugin_files) do
		local filename = vim.fn.fnamemodify(file, ":t:r")

		if filename ~= "init" then
			local status, plugin_config = pcall(require, "plugins." .. filename)
			if status then
				if type(plugin_config) == "table" then
					table.insert(plugin_configs, plugin_config)
				else
					vim.notify("Plugin " .. filename .. " not return a table", vim.log.levels.WARN)
				end
			else
				vim.notify("Can't load plugin: " .. filename .. " - " .. plugin_config, vim.log.levels.ERROR)
			end
		end
	end

	return plugin_configs
end

return M
