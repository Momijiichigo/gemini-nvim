local M = {}

local bufnr = nil
local winid = nil
local augroup = vim.api.nvim_create_augroup("GeminiTerminal", { clear = true })

local function enforce_right_position()
  if winid and vim.api.nvim_win_is_valid(winid) then
    local current_win = vim.api.nvim_get_current_win()
    vim.api.nvim_set_current_win(winid)
    vim.cmd("wincmd L")
    vim.api.nvim_set_current_win(current_win)
  end
end

function M.open(cmd_args, opts)
  opts = opts or {}
  local split_side = opts.split_side or "right"
  local split_width = opts.split_width or 0.3

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    -- Check if visible
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      winid = wins[1]
      vim.api.nvim_set_current_win(winid)
      enforce_right_position()
      return
    end
    -- Not visible, create split
  end

  local width = math.floor(vim.o.columns * split_width)
  -- Always use botright for gemini-nvim to start at the edge
  local modifier = "botright "
  
  vim.cmd(modifier .. width .. "vsplit")
  winid = vim.api.nvim_get_current_win()
  vim.wo[winid].winfixwidth = true

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(winid, bufnr)
  else
    vim.cmd("enew")
    bufnr = vim.api.nvim_get_current_buf()

    -- Ensure autoread is on so checktime works better
    vim.o.autoread = true
    
    -- Trigger checktime when entering the terminal to pick up changes from the CLI
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermEnter" }, {
      group = augroup,
      buffer = bufnr,
      callback = function()
        vim.cmd("checktime")
      end,
    })
    
    local cmd = { "gemini" }
    if cmd_args then
      for _, arg in ipairs(cmd_args) do
        table.insert(cmd, arg)
      end
    end

    vim.fn.termopen(cmd, {
      env = {
        NVIM = vim.v.servername,
        NVIM_LISTEN_ADDRESS = vim.v.servername,
      },
      on_exit = function()
        bufnr = nil
        if winid and vim.api.nvim_win_is_valid(winid) then
          vim.api.nvim_win_close(winid, true)
        end
        vim.api.nvim_clear_autocmds({ group = augroup })
      end
    })

    -- Enforce position when a new window is created
    vim.api.nvim_create_autocmd({ "WinNew", "BufWinEnter" }, {
      group = augroup,
      callback = function()
        vim.schedule(enforce_right_position)
      end,
    })

    -- Fallback for pre-0.10: Ensure the buffer remains Gemini's in its dedicated window
    if vim.fn.has("nvim-0.10") == 0 then
      vim.api.nvim_create_autocmd("BufEnter", {
        group = augroup,
        callback = function()
          local cur_win = vim.api.nvim_get_current_win()
          if cur_win == winid and bufnr and vim.api.nvim_buf_is_valid(bufnr) then
            local cur_buf = vim.api.nvim_get_current_buf()
            if cur_buf ~= bufnr then
              vim.api.nvim_win_set_buf(winid, bufnr)
            end
          end
        end,
      })
    end
  end

  -- Prevent the window from being overridden by other buffers
  -- This must happen AFTER the buffer is set to avoid E1513
  if vim.fn.has("nvim-0.10") == 1 then
    vim.wo[winid].winfixbuf = true
  end
  
  vim.cmd("startinsert")
end

function M.toggle(cmd_args, opts)
  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      vim.api.nvim_win_close(wins[1], true)
      return
    end
  end
  M.open(cmd_args, opts)
end

return M
