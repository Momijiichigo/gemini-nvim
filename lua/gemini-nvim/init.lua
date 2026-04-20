local M = {}
local mcp = require("gemini-nvim.mcp")
local terminal = require("gemini-nvim.terminal")

local config = {
  split_side = "right",
  split_width = 0.3,
  debug = false,
}

function M.setup(opts)
  config = vim.tbl_deep_extend("force", config, opts or {})
  
  -- Enable autoread globally
  vim.o.autoread = true
  
  -- Trigger checktime on FocusGained and when entering buffers
  local group = vim.api.nvim_create_augroup("GeminiAutoUpdate", { clear = true })
  vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "WinEnter" }, {
    group = group,
    callback = function()
      if vim.api.nvim_get_mode().mode ~= "c" then
        vim.cmd("checktime")
      end
    end,
  })
end

function M.handle_edit(file_path, new_content)
  local diff = require("gemini-nvim.diff")
  -- Use vim.fn.bufnr with the full path to avoid issues with relative names
  local full_path = vim.fn.fnamemodify(file_path, ":p")
  local bufnr = vim.fn.bufnr(full_path)
  
  if config.debug then
    vim.notify(string.format("gemini-nvim: handle_edit called for %s (bufnr: %d)", full_path, bufnr), vim.log.levels.INFO)
  end

  if bufnr == -1 then
    -- If file not in buffer, open it first
    bufnr = vim.fn.bufadd(full_path)
    vim.fn.bufload(bufnr)
    if config.debug then
      vim.notify(string.format("gemini-nvim: Buffer added for %s (new bufnr: %d)", full_path, bufnr), vim.log.levels.INFO)
    end
  end

  diff.apply_changes(bufnr, new_content)
end

function M.start_chat(prompt)
  -- Go up 4 levels from lua/gemini-nvim/init.lua to reach workspace root
  local workspace_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h:h")
  local launcher = workspace_root .. "/coc-nvim-mcp/coc-mcp-launcher.sh"
  
  local launcher_cmd = launcher
  if config.debug then
    launcher_cmd = launcher .. " --debug"
  end

  local add_cmd = { "gemini", "mcp", "add", "coc-nvim-mcp", launcher_cmd }

  -- Register/Update the MCP server in gemini CLI
  -- We include NVIM in the environment to ensure the registration happens in the same context
  vim.system(add_cmd, { text = true, env = { NVIM = vim.v.servername } }, function(obj)
    vim.schedule(function()
      if obj.code ~= 0 then
        vim.notify("gemini-nvim: Failed to register MCP server: " .. (obj.stderr or "unknown error"), vim.log.levels.ERROR)
      end
      
      local cmd_args = nil
      if prompt and prompt ~= "" then
        cmd_args = { "-i", prompt }
      end
      terminal.toggle(cmd_args, config)
    end)
  end)
end

return M
