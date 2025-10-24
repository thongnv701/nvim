return {
  "folke/flash.nvim",
  event = "VeryLazy",
  opts = {},
  keys = {
    {
      "s",
      mode = { "n", "x", "o" },
      function() require("flash").jump() end,
      desc = "Flash jump",
    },
    {
      "gs",
      mode = { "n", "o", "x" },
      function()
        require("flash").treesitter({
          actions = {
            ["gs"] = "next",
            ["<BS>"] = "prev",
          },
        })
      end,
      desc = "Flash Treesitter selection",
    },
  },
}
