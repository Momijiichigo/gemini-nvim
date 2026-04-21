local M = {}
local watchers = {}

-- Function to start watching a buffer
function M.watch_buffer(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local filepath = vim.api.nvim_buf_get_name(bufnr)

  -- Don't watch if it's not a real file, already being watched, or doesn't exist
  if filepath == "" or watchers[bufnr] or vim.fn.filereadable(filepath) == 0 then
    return
  end

  -- Create a new file system event watcher
  local watcher = vim.uv.new_fs_event()
  if not watcher then return end
  
  watchers[bufnr] = watcher

  -- Start watching the file path
  watcher:start(filepath, {}, vim.schedule_wrap(function(err, filename, events)
    if err then
      -- Silently fail or log if debug is enabled
      return
    end
    
    -- When the OS reports a change, force Neovim to check the file
    if vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_buf_call(bufnr, function()
        vim.cmd("silent! checktime")
      end)
    end
  end))
  
  -- Cleanup watcher when the buffer is wiped
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = bufnr,
    once = true,
    callback = function()
      if watchers[bufnr] then
        watchers[bufnr]:stop()
        watchers[bufnr] = nil
      end
    end,
  })
end

function M.setup()
  -- Automatically watch buffers when they are read or created
  local group = vim.api.nvim_create_augroup("GeminiWatcher", { clear = true })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
    group = group,
    pattern = "*",
    callback = function(args)
      M.watch_buffer(args.buf)
    end,
  })
  
  -- Also watch already open buffers
  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(bufnr) then
      M.watch_buffer(bufnr)
    end
  end
end

return M
