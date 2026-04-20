local M = {}

function M.show_diff(original_buf, new_content)
  local ft = vim.bo[original_buf].filetype
  
  -- Create scratch buffer
  local scratch_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[scratch_buf].filetype = ft
  vim.bo[scratch_buf].buftype = "nofile"
  vim.bo[scratch_buf].bufhidden = "wipe"
  vim.bo[scratch_buf].swapfile = false
  
  -- Set new content in scratch buffer
  local lines = vim.split(new_content, "\n")
  vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, lines)
  
  -- Split and show
  vim.cmd("vsplit")
  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, scratch_buf)
  
  -- Diff mode
  vim.cmd("diffthis")
  vim.api.nvim_win_call(vim.fn.bufwinid(original_buf), function()
    vim.cmd("diffthis")
  end)
  
  -- Keymaps for scratch buffer
  vim.keymap.set("n", "<Cmd>w<CR>", function()
    -- Accept changes: diffget from scratch to original
    -- Or just replace the original buffer content
    vim.api.nvim_buf_set_lines(original_buf, 0, -1, false, lines)
    vim.api.nvim_buf_delete(scratch_buf, { force = true })
    vim.api.nvim_win_call(vim.fn.bufwinid(original_buf), function()
      vim.cmd("diffoff")
      vim.cmd("write")
    end)
  end, { buffer = scratch_buf, silent = true })
  
  vim.keymap.set("n", "<Cmd>q<CR>", function()
    -- Abort: close scratch
    vim.api.nvim_buf_delete(scratch_buf, { force = true })
    vim.api.nvim_win_call(vim.fn.bufwinid(original_buf), function()
      vim.cmd("diffoff")
    end)
  end, { buffer = scratch_buf, silent = true })
end

return M
