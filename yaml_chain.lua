local M = {}

-- Parse YAML block into Lua table.
-- This is primitive but enough for front-matter blocks.
local function parse_yaml_block(lines, start_idx, end_idx)
  local result = {}

  for i = start_idx, end_idx do
    local line = lines[i]
    -- match "key: value" OR "key:"
    local key, val = line:match("^%s*(%w+):%s*(.*)$")
    if key then
      if val == "" then
        -- list start, like "prev:"
        result[key] = {}
      else
        result[key] = val
      end
    elseif line:match("^%s*%-%s*(.+)$") then
      -- list item like "- 001"
      local item = line:match("^%s*%-%s*(.+)$")
      -- find which key we are under
      local last_key = nil
      for k, v in pairs(result) do
        if type(v) == "table" then
          last_key = k
        end
      end
      if last_key then
        table.insert(result[last_key], item)
      end
    end
  end

  return result
end

-- Serialize Lua table back into YAML front matter
local function serialize_yaml_block(data)
  local out = { "---" }

  for k, v in pairs(data) do
    if type(v) == "table" then
      table.insert(out, k .. ":")
      for _, item in ipairs(v) do
        table.insert(out, "  - " .. item)
      end
    else
      table.insert(out, k .. ": " .. v)
    end
  end

  table.insert(out, "---")
  return out
end

local function generate_id()
  return tostring(os.time())
end

-- Keep last opened ID in memory
local last_id = nil

-- Ensure id exists, read YAML, patch prev/next logic.
function M.process_current_file()
  local bufnr = vim.api.nvim_get_current_buf()
  local fname = vim.api.nvim_buf_get_name(bufnr)
  if not fname:match("%.md$") then
    return
  end

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  if lines[1] ~= "---" then
    return
  end

  -- find yaml end
  local yaml_end
  for i = 2, #lines do
    if lines[i] == "---" then
      yaml_end = i
      break
    end
  end
  if not yaml_end then return end

  local yaml = parse_yaml_block(lines, 2, yaml_end - 1)

  -- ensure id
  if not yaml.id then
    yaml.id = generate_id()
  end

  local this_id = yaml.id

  -- update prev from last_id
  if last_id and last_id ~= this_id then
    yaml.prev = yaml.prev or {}

    -- remove duplicate if exists
    local cleaned = {}
    for _, item in ipairs(yaml.prev) do
      if item ~= last_id then
        table.insert(cleaned, item)
      end
    end

    table.insert(cleaned, 1, last_id)
    while #cleaned > 3 do
      table.remove(cleaned, #cleaned)
    end

    yaml.prev = cleaned
  end

  -- update next of last file
  if last_id and last_id ~= this_id then
    -- find that buffer by filename
    -- We can track last buffer separately to avoid searching.
    -- Simpler: store last filename.
    if M._last_bufnr and vim.api.nvim_buf_is_valid(M._last_bufnr) then
      local other_lines = vim.api.nvim_buf_get_lines(M._last_bufnr, 0, -1, false)
      if other_lines[1] == "---" then
        local o_end
        for i = 2, #other_lines do
          if other_lines[i] == "---" then
            o_end = i
            break
          end
        end
        if o_end then
          local oyaml = parse_yaml_block(other_lines, 2, o_end - 1)

          oyaml.next = oyaml.next or {}

          -- remove duplicate
          local cleaned = {}
          for _, item in ipairs(oyaml.next) do
            if item ~= this_id then
              table.insert(cleaned, item)
            end
          end

          table.insert(cleaned, 1, this_id)
          while #cleaned > 3 do
            table.remove(cleaned, #cleaned)
          end

          oyaml.next = cleaned

          local new_o_lines = serialize_yaml_block(oyaml)
          for i = o_end + 1, #other_lines do
            table.insert(new_o_lines, other_lines[i])
          end

          vim.api.nvim_buf_set_lines(M._last_bufnr, 0, -1, false, new_o_lines)
        end
      end
    end
  end

  -- write YAML back for current note
  local new_yaml = serialize_yaml_block(yaml)
  for i = yaml_end + 1, #lines do
    table.insert(new_yaml, lines[i])
  end

  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_yaml)

  -- set last markers
  last_id = this_id
  M._last_bufnr = bufnr
end

return M

