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
