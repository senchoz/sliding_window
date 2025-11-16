local M = {}

function M.show_recent()
  local files = vim.v.oldfiles or {}
  local lines = {}

  for i = 1, math.min(3, #files) do
    table.insert(lines, files[i])
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  local width = 60
  local height = #lines
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = 5,
    col = 5,
    style = "minimal",
    border = "rounded"
  })

  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M

