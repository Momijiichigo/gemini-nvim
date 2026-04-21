local M = {}
local mcp = require("gemini-nvim.mcp")
local terminal = require("gemini-nvim.terminal")
local watcher = require("gemini-nvim.watcher")

local config = {
  split_side = "right",
  split_width = 0.3,
  debug = false,
  coc_mcp = false,
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  
  -- Enable autoread globally for auto-update from CLI
  vim.o.autoread = true
  
  -- Trigger checktime on common events to pick up CLI changes
  local group = vim.api.nvim_create_augroup("GeminiAutoUpdate", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "WinEnter", "TermEnter" }, {
    group = group,
    callback = function()
      if vim.api.nvim_get_mode().mode ~= "c" then
        vim.cmd("silent! checktime")
      end
    end,
  })

  -- Start proactive file watching
  watcher.setup()

  M.config = config
end

function M.handle_edit(file_path, new_content)
  local full_path = vim.fn.fnamemodify(file_path, ":p")
  local bufnr = vim.fn.bufnr(full_path)
  
  if bufnr == -1 then
    bufnr = vim.fn.bufadd(full_path)
    vim.fn.bufload(bufnr)
  end

  local lines = vim.split(new_content, "\n", { plain = true })
  if lines[#lines] == "" then
    table.remove(lines, #lines)
  end
  
  -- Apply changes directly to the buffer
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  
  -- Always try to save the buffer
  vim.api.nvim_buf_call(bufnr, function()
    vim.cmd("silent! write")
  end)
end

function M.initialize_mcp()
  -- Go up 4 levels from lua/gemini-nvim/init.lua to reach workspace root
  local workspace_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h:h")
  local launcher = workspace_root .. "/coc-nvim-mcp/coc-mcp-launcher.sh"
  local skill_file = workspace_root .. "/coc-nvim-mcp/skill"
  
  local launcher_cmd = launcher
  if config.debug then
    launcher_cmd = launcher .. " --debug"
  end

  -- We use a terminal buffer for initialization because gemini skills install
  -- may require interactive consent from the user.
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.8)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2),
    style = "minimal",
    border = "rounded",
    title = " Gemini Initialization ",
    title_pos = "center",
  })

  local add_cmd = string.format("gemini mcp add -s user --trust coc-nvim-mcp %s", vim.fn.shellescape(launcher_cmd))
  local skill_cmd = string.format("gemini skills install %s --scope user", vim.fn.shellescape(skill_file))
  local full_cmd = add_cmd .. " && " .. skill_cmd

  vim.fn.termopen(full_cmd, {
    env = { NVIM = vim.v.servername },
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          if vim.api.nvim_win_is_valid(win) then
            vim.api.nvim_win_close(win, true)
          end
          vim.notify("gemini-nvim: MCP server and skill registered successfully", vim.log.levels.INFO)
        else
          vim.notify("gemini-nvim: Initialization failed with code " .. code .. ". Check the terminal buffer for details.", vim.log.levels.ERROR)
        end
      end)
    end
  })
  
  vim.cmd("startinsert")
end

function M.start_chat(prompt)
  local cmd_args = nil
  if prompt and prompt ~= "" then
    cmd_args = { "-i", prompt }
  end
  terminal.toggle(cmd_args, config)
end

return M
