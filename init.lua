local M = {}

-- Re-export submodules in a controlled way
local popup  = require("sliding_window.popup")
local recent = require("sliding_window.recent")

require("sliding_window.yaml_id")

function M.popup()
  return popup.show_popup()
end

function M.recent()
  return recent.show_recent()
end

return M

