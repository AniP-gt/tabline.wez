local M = {}

-- Process names that indicate a remote connection
local remote_processes = {
  'ssh',
  'mosh',
  'mosh%-client',
  'mosh%-server',
  'ssm',
  'aws',
}

-- Title patterns that indicate a remote connection
local remote_title_patterns = {
  '^ssh%s',        -- "ssh user@host"
  '^ssh$',         -- just "ssh"
  'ssh%s+%S',      -- "ssh ..." anywhere
  '^mosh%s',       -- "mosh user@host"
  '^mosh$',
  'aws%s+ssm',     -- "aws ssm start-session"
  'ssm%s+start',   -- "ssm start-session"
  '@',             -- user@host pattern (common in SSH titles)
}

-- Domain names that are local (not remote)
local local_domains = {
  ['local'] = true,
  ['local_mux'] = true,
  [''] = true,
}

local function is_remote_pane(pane)
  -- Check foreground_process_name (works for local panes, empty for mux panes)
  if pane.foreground_process_name and pane.foreground_process_name ~= '' then
    local process = pane.foreground_process_name:match('([^/\\]+)[/\\]?$') or pane.foreground_process_name
    process = process:lower()
    for _, remote_proc in ipairs(remote_processes) do
      if process:match('^' .. remote_proc) then
        return true
      end
    end
  end

  -- Check pane title (works for mux panes via OSC escape sequences)
  if pane.title and pane.title ~= '' then
    local title = pane.title:lower()
    for _, pattern in ipairs(remote_title_patterns) do
      if title:match(pattern) then
        return true
      end
    end
  end

  -- Check domain_name for truly remote domains (SSH domain, etc.)
  if pane.domain_name and not local_domains[pane.domain_name] then
    return true
  end

  -- Check user_vars if available (shell integration can set these)
  if pane.user_vars then
    if pane.user_vars.WEZTERM_REMOTE == 'true' or pane.user_vars.WEZTERM_REMOTE == '1' then
      return true
    end
  end

  return false
end

function M.is_remote_tab(tab)
  if not tab or not tab.panes then
    return false
  end
  for _, pane in ipairs(tab.panes) do
    if is_remote_pane(pane) then
      return true
    end
  end
  return false
end

--- Check if any pane in the given workspace has a remote connection.
--- Uses wezterm.mux API to enumerate windows/tabs/panes.
--- @param workspace_name string
--- @return boolean
function M.is_remote_workspace(workspace_name)
  local wezterm = require('wezterm')
  for _, mux_win in ipairs(wezterm.mux.all_windows()) do
    if mux_win:get_workspace() == workspace_name then
      for _, tab in ipairs(mux_win:tabs()) do
        for _, pane_info in ipairs(tab:panes_with_info()) do
          -- DEBUG: log pane_info keys to understand structure
          local keys = {}
          for k, _ in pairs(pane_info) do
            table.insert(keys, k)
          end
          wezterm.log_info('WORKSPACE PANE keys: ' .. table.concat(keys, ', '))
          wezterm.log_info('WORKSPACE PANE user_vars: ' .. tostring(pane_info.user_vars))
          if pane_info.pane then
            local uv = pane_info.pane:get_user_vars()
            wezterm.log_info('WORKSPACE PANE pane:get_user_vars(): ' .. wezterm.json_encode(uv))
          end
          if is_remote_pane(pane_info) then
            return true
          end
        end
      end
    end
  end
  return false
end

return M
