-- Workspace layout system: called by `context startup layout <name>`
-- Define your layouts here, then reference them in .context-startup.toml

local function getMainDisplay()
  return hs.screen.mainScreen()
end

local function positionWindow(win, x, y, w, h)
  if not win then
    return false
  end
  local frame = win:frame()
  frame.x = x
  frame.y = y
  frame.w = w
  frame.h = h
  win:setFrame(frame)
  return true
end

local function getDisplayDimensions()
  local screen = getMainDisplay()
  local frame = screen:frame()
  return frame.w, frame.h, frame.x, frame.y
end

-- Resize split: move boundary between two side-by-side windows
-- leftPercent: 0-100, width of left window as percentage of screen
function resizeSplit(leftPercent)
  if not leftPercent or leftPercent < 10 or leftPercent > 90 then
    print("[resize-split] invalid percentage: " .. tostring(leftPercent))
    return false
  end

  local w, h, x, y = getDisplayDimensions()
  local windows = hs.window.visibleWindows()

  if #windows < 2 then
    print("[resize-split] need at least 2 windows; found " .. #windows)
    return false
  end

  -- Sort by x position (left to right)
  table.sort(windows, function(a, b)
    return a:frame().x < b:frame().x
  end)

  local leftWindow = windows[1]
  local rightWindow = windows[2]

  local leftWidth = (w * leftPercent) / 100
  local rightWidth = w - leftWidth

  positionWindow(leftWindow, x, y, leftWidth, h)
  positionWindow(rightWindow, x + leftWidth, y, rightWidth, h)

  print(string.format("[resize-split] left: %.0f%%, right: %.0f%%",
                      leftPercent, 100 - leftPercent))
  return true
end

-- Cycle through preset split sizes: 50 → 66 → 75 → 50
function cycleSplitSize()
  -- Try to read current state from a temp file
  local stateFile = os.getenv("HOME") .. "/.cache/context/split-state"
  local currentSize = 50

  local f = io.open(stateFile, "r")
  if f then
    local line = f:read("*n")
    if line then
      currentSize = line
    end
    f:close()
  end

  -- Cycle: 50 → 66 → 75 → 50
  local nextSize = 50
  if currentSize == 50 then
    nextSize = 66
  elseif currentSize == 66 then
    nextSize = 75
  elseif currentSize == 75 then
    nextSize = 50
  end

  -- Write new state
  local dir = os.getenv("HOME") .. "/.cache/context"
  os.execute("mkdir -p '" .. dir .. "'")
  f = io.open(stateFile, "w")
  if f then
    f:write(tostring(nextSize))
    f:close()
  end

  return resizeSplit(nextSize)
end

-- Apply a named workspace layout
function applyWorkspaceLayout(layoutName)
  if not layoutName or layoutName == "" then
    print("[workspace-layout] layout name is empty")
    return false
  end

  -- Get all windows in the current AeroSpace workspace
  local workspace = hs.execute("aerospace list-windows --focused", true)
  if not workspace or workspace == "" then
    print("[workspace-layout] could not get current workspace")
    return false
  end
  workspace = workspace:gsub("\n$", "")

  -- Define your layouts here
  local layouts = {
    ["main-work"] = function(windows)
      -- Example: split screen 2/3 left, 1/3 right
      -- Customize this based on your app names and desired ratios
      if #windows == 0 then
        print("[workspace-layout] no windows in workspace")
        return false
      end

      local w, h, x, y = getDisplayDimensions()
      local third = w / 3

      -- Position first window to left 2/3
      if windows[1] then
        positionWindow(windows[1], x, y, w * 2/3, h)
      end

      -- Position remaining windows to right 1/3
      for i = 2, #windows do
        if windows[i] then
          positionWindow(windows[i], x + w * 2/3, y, w / 3, h)
        end
      end
      return true
    end,

    ["fullscreen"] = function(windows)
      -- Maximize all windows
      for _, win in ipairs(windows) do
        if win then
          win:maximize()
        end
      end
      return true
    end,

    ["equal-split"] = function(windows)
      -- Equal-width columns
      if #windows == 0 then
        return false
      end

      local w, h, x, y = getDisplayDimensions()
      local colWidth = w / #windows

      for i, win in ipairs(windows) do
        if win then
          positionWindow(win, x + (i-1) * colWidth, y, colWidth, h)
        end
      end
      return true
    end,
  }

  local layoutFn = layouts[layoutName]
  if not layoutFn then
    print(string.format("[workspace-layout] unknown layout: %s", layoutName))
    return false
  end

  -- Get all windows (currently this is a simple approach; for more precision,
  -- query AeroSpace's window list and filter by workspace)
  local allWindows = hs.window.allWindows()
  if #allWindows == 0 then
    print("[workspace-layout] no windows found")
    return false
  end

  -- TODO: filter to only windows in the focused workspace
  -- For now, apply to all visible windows

  local success = layoutFn(allWindows)
  if success then
    print(string.format("[workspace-layout] applied layout: %s", layoutName))
  else
    print(string.format("[workspace-layout] failed to apply layout: %s", layoutName))
  end
  return success
end
