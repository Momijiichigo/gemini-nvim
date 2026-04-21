vim.api.nvim_create_user_command("Gemini", function(opts)

  require("gemini-nvim").start_chat()

end, { nargs = "*", range = true })

vim.api.nvim_create_user_command("GeminiInit", function()
  local gemini_nvim = require("gemini-nvim")
  if gemini_nvim.config.coc_mcp then
    gemini_nvim.initialize_mcp()
  end
end, {})
