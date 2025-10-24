return {
  "rmagatti/auto-session",
  lazy = false,
  config = function()
    -- Set sessionoptions to include 'localoptions' for proper filetype and highlighting
    vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

    require("auto-session").setup({
      log_level = "info",
      auto_session_enable_last_session = true,
      auto_session_root_dir = vim.fn.stdpath("data") .. "/sessions/",
      auto_save_enabled = true,
      auto_restore_enabled = true,
    })
  end,
}
