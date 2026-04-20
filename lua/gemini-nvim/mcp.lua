local M = {}

function M.get_server_command()
  local workspace_root = vim.fn.fnamemodify(debug.getinfo(1).source:sub(2), ":h:h:h:h")
  local launcher = workspace_root .. "/coc-nvim-mcp/coc-mcp-launcher.sh"
  return { launcher }
end

return M
