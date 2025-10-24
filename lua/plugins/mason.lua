return {
    "williamboman/mason.nvim",
    config = function()
        require("mason").setup({
            ui = {
                icons = {
                    package_installed = "✓",
                    package_pending = "➜",
                    package_uninstalled = "✗"
                }
            },
            registries = {"github:mason-org/mason-registry", "github:Crashdummyy/mason-registry"},
        })
        
        -- Ensure Java and Rust debug adapters are installed
        local mason_registry = require("mason-registry")
        local packages_to_install = {"java-debug-adapter", "java-test", "codelldb", "jdtls"}
        
        for _, package in ipairs(packages_to_install) do
            if not mason_registry.is_installed(package) then
                vim.notify("Installing " .. package .. "...", vim.log.levels.INFO)
                mason_registry.get_package(package):install()
            end
        end
    end
}
