vim.api.nvim_create_user_command("Gemini", function(opts)
  local prompt = opts.args
  if prompt == "" and opts.range == 0 then
    -- Toggle if no args and no range
    require("gemini-nvim").start_chat()
    return
  end
  
  if opts.range ~= 0 then
    local lines = vim.api.nvim_buf_get_lines(0, opts.line1 - 1, opts.line2, false)
    local content = table.concat(lines, "\n")
    prompt = prompt .. "\n\nContext from selection:\n```\n" .. content .. "\n```"
  end

  require("gemini-nvim").start_chat(prompt)
end, { nargs = "*", range = true })
