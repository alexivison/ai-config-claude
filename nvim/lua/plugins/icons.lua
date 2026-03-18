local function make_icons_colorless()
  for _, prefix in ipairs({ "MiniIcons", "DevIcon" }) do
    for _, hl in ipairs(vim.fn.getcompletion(prefix, "highlight")) do
      vim.api.nvim_set_hl(0, hl, { link = "Normal" })
    end
  end
end

return {
  {
    "nvim-mini/mini.icons",
    opts = function(_, opts)
      opts.style = "glyph"
    end,
    config = function(_, opts)
      require("mini.icons").setup(opts)

      local group = vim.api.nvim_create_augroup("colorless_icons", { clear = true })
      vim.api.nvim_create_autocmd("ColorScheme", {
        group = group,
        callback = make_icons_colorless,
      })

      make_icons_colorless()
    end,
  },
}
