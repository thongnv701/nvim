local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
    vim.fn.system({"git", "clone", "--filter=blob:none", "https://github.com/folke/lazy.nvim.git", "--branch=stable",
                   lazypath})
end
vim.opt.rtp:prepend(lazypath)

-- Prevent lspconfig's legacy jdtls loader from interfering; ftplugin handles Java
package.preload['lspconfig.server_configurations.jdtls'] = function()
    return {}
end

require('configurations.keymaps').setup()
require('configurations.options').setup()

require("lazy").setup(require("configurations.plugins").setup(), {
    checker = {
        enabled = true,
        notify = false
    },
    change_detection = {
        notify = false
    },
    rocks = {
        enabled = false
    }
})

-- jdtls will be started by the plugin config when editing Java files
