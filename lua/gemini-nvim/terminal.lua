local M = {}

local bufnr = nil
local winid = nil
local augroup = vim.api.nvim_create_augroup("GeminiTerminal", { clear = true })

function M.open(cmd_args, opts)
  opts = opts or {}
  local split_side = opts.split_side or "right"
  local split_width = opts.split_width or 0.3

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    local wins = vim.fn.win_findbuf(bufnr)
    if #wins > 0 then
      winid = wins[1]
      vim.api.nvim_set_current_win(winid)
      return
    end
  end

  local width = math.floor(vim.o.columns * split_width)
  if width < 20 then width = 40 end -- Sanity check
  
  local modifier = "botright "
  vim.cmd(modifier .. width .. "vsplit")
  winid = vim.api.nvim_get_current_win()
  vim.wo[winid].winfixwidth = true

  if bufnr and vim.api.nvim_buf_is_valid(bufnr) then
    vim.api.nvim_win_set_buf(winid, bufnr)
  else
    vim.cmd("enew")
    bufnr = vim.api.nvim_get_current_buf()

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
      on_exit = function(_, exit_code)
        if exit_code ~= 0 and exit_code ~= 130 then -- 130 is Ctrl-C
          vim.schedule(function()
            vim.notify("Gemini process exited with code " .. exit_code, vim.log.levels.ERROR)
          end)
        end
        
        bufnr = nil
        if winid and vim.api.nvim_win_is_valid(winid) then
          vim.api.nvim_win_close(winid, true)
        end
        winid = nil
      end
    })

    -- Trigger checktime when entering the terminal to pick up changes from the CLI
    vim.api.nvim_create_autocmd({ "BufEnter", "WinEnter", "TermEnter" }, {
      group = augroup,
      buffer = bufnr,
      callback = function()
        vim.cmd("silent! checktime")
      end,
    })
  end

  -- Prevent the window from being overridden by other buffers (Neovim 0.10+)
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
