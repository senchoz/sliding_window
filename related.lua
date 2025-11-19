local M = {}

local function generate_id()
  return tostring(os.time())
end

local function ensure_yaml(bufnr)
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  if #lines == 0 or lines[1] ~= "---" then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
      "---",
      "id: " .. generate_id(),
      "related:",
      "---",
      ""
    })
    return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  end

  return lines
end

local function extract_yaml(lines)
  local yaml_end
  for i = 2, #lines do
    if lines[i] == "---" then
      yaml_end = i
      break
    end
  end
  if not yaml_end then return nil end
  return 1, yaml_end
end

local function parse_yaml(lines, y_start, y_end)
  local yaml = { id = nil, related = {} }

  for i = y_start + 1, y_end - 1 do
    local line = lines[i]

    local key, value = line:match("^%s*(%w+):%s*(.*)$")
    if key == "id" then
      yaml.id = value
    elseif key == "related" then
      -- list lines come after this
      local j = i + 1
      while j < y_end do
        local item = lines[j]:match("^%s*%-[%s]*(.*)$")
        if not item then break end
        table.insert(yaml.related, item)
        j = j + 1
      end
    end
  end

  return yaml
end

local function rewrite_yaml(bufnr, lines, y_start, y_end, yaml)
  local new = { lines[y_start] }

  table.insert(new, "id: " .. yaml.id)
  table.insert(new, "related:")

  for _, item in ipairs(yaml.related) do
    table.insert(new, "- " .. item)
  end

  table.insert(new, "---")

  vim.api.nvim_buf_set_lines(bufnr, y_start - 1, y_end, false, new)
end

local function update_related(yaml, current_id, max_items)
  if not current_id or yaml.id == current_id then
    return
  end

  local new = {}
  new[1] = current_id

  local seen = { [current_id] = true }

  for _, id in ipairs(yaml.related) do
    if not seen[id] then
      table.insert(new, id)
      seen[id] = true
    end
  end

  while #new > max_items do
    table.remove(new)
  end

  yaml.related = new
end

function M.on_event()
  local bufnr = vim.api.nvim_get_current_buf()

  vim.schedule(function()
    local lines = ensure_yaml(bufnr)
    local y_start, y_end = extract_yaml(lines)
    if not y_start then return end

    local yaml = parse_yaml(lines, y_start, y_end)

    if not yaml.id then
      yaml.id = generate_id()
    end
    if not yaml.related then
      yaml.related = {}
    end

    local prev_buf = vim.g.sliding_window_last_bufid
    local prev_id = vim.g.sliding_window_last_id

    if prev_buf
      and vim.api.nvim_buf_is_valid(prev_buf)
      and prev_buf ~= bufnr
    then
      update_related(yaml, prev_id, 5)
    end

    rewrite_yaml(bufnr, lines, y_start, y_end, yaml)

    vim.g.sliding_window_last_bufid = bufnr
    vim.g.sliding_window_last_id = yaml.id
  end)
end

return M

