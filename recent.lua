local M = {}

function M.show_recent()
  local files = vim.v.oldfiles or {}
  local lines = {}

  for i = 1, math.min(3, #files) do
    lines[i] = files[i]
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
    border = "rounded",
  })

  -- Quit with q
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })

  -- Open file with Enter
  vim.keymap.set("n", "<CR>", function()
    -- get cursor line (1-indexed)
    local cursor = vim.api.nvim_win_get_cursor(win)
    local lnum = cursor[1]

    local filename = lines[lnum]
    if not filename then
      return
    end

    vim.api.nvim_win_close(win, true)
    vim.cmd("edit " .. filename)
  end, { buffer = buf })

end

return M

