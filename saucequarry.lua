-- quarry_plus_stable.lua
-- ✔ Skips top 2 surface layers horizontally
-- ✔ Mines the requested rectangle perfectly
-- ✔ Auto-refuels / auto-unloads and resumes
-- ✔ Returns home after the final slice

-------------------------------------------------------------------- CONFIG
local FUEL_SLOT        = 16
local SEGMENTS         = 4            -- divide total depth into this many passes
local FUEL_PER_BLOCK   = 3            -- dig + move estimate
local SAFE_MARGIN      = 40           -- extra fuel buffer
local RETURN_MARGIN    = 15           -- fuel kept in reserve to get home
local DIG_RETRY_MAX    = 20

-------------------------------------------------------------------- STATE
local pos = {x = 0, y = 0, z = 0}     -- turtle-relative coords
local dir = 0                         -- 0:+X 1:+Z 2:-X 3:-Z

-------------------------------------------------------------------- NAV HELPERS
local function face(d) while dir ~= d do turtle.turnRight(); dir = (dir + 1) % 4 end end
local function turnLeft()  turtle.turnLeft();  dir = (dir + 3) % 4 end
local function turnRight() turtle.turnRight(); dir = (dir + 1) % 4 end

local function fwd()
  for _ = 1, DIG_RETRY_MAX do
    if turtle.forward() then
      if     dir == 0 then pos.x = pos.x + 1
      elseif dir == 1 then pos.z = pos.z + 1
      elseif dir == 2 then pos.x = pos.x - 1
      else               pos.z = pos.z - 1 end
      return true
    end
    turtle.dig(); turtle.attack(); sleep(0.2)
  end
  error("Unbreakable block ahead.")
end

local function up()
  for _ = 1, DIG_RETRY_MAX do
    if turtle.up() then pos.y = pos.y + 1; return true end
    turtle.digUp(); turtle.attackUp(); sleep(0.2)
  end
  error("Unbreakable block above.")
end

local function down()
  for _ = 1, DIG_RETRY_MAX do
    if turtle.down() then pos.y = pos.y - 1; return true end
    turtle.digDown(); turtle.attackDown(); sleep(0.2)
  end
  error("Unbreakable block below.")
end

local function distanceHome()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z)
end

-------------------------------------------------------------------- FUEL
local function ensureFuel(minimum)
  if turtle.getFuelLevel() == "unlimited" then return end
  local startDir = dir
  face((startDir + 3) % 4)                -- look at left chest
  turtle.select(FUEL_SLOT)
  while turtle.getFuelLevel() < minimum do
    if not turtle.suck(1) then
      print("Waiting for fuel… need", minimum - turtle.getFuelLevel())
      sleep(10)
    else
      turtle.refuel()
    end
  end
  face(startDir); turtle.select(1)
end

-------------------------------------------------------------------- INVENTORY
local function isInventoryFull()
  for s = 1, 15 do
    if turtle.getItemCount(s) == 0 then return false end
  end
  return true
end

local function dumpInventory()
  turtle.select(1)
  turnLeft(); turnLeft()                -- face rear chest
  for s = 1, 15 do
    if s ~= FUEL_SLOT and turtle.getItemCount(s) > 0 then
      turtle.select(s); turtle.drop()
    end
  end
  turtle.select(1)
  turnLeft(); turnLeft()                -- face forward again
end

-------------------------------------------------------------------- GO HOME & RESUME
local function goHome()                 -- back to (0,0,0) facing +X
  while pos.y < 0 do up()   end
  while pos.y > 0 do down() end
  if pos.z > 0 then face(3) while pos.z > 0 do fwd() end
  elseif pos.z < 0 then face(1) while pos.z < 0 do fwd() end end
  if pos.x > 0 then face(2) while pos.x > 0 do fwd() end
  elseif pos.x < 0 then face(0) while pos.x < 0 do fwd() end end
  face(0)
end

local function resumeFrom(saved)
  -- vertical first
  while pos.y > saved.y do down() end
  while pos.y < saved.y do up()   end
  -- Z axis
  if saved.z > 0 then face(1) while pos.z < saved.z do fwd() end
  elseif saved.z < 0 then face(3) while pos.z > saved.z do fwd() end end
  -- X axis
  if saved.x > 0 then face(0) while pos.x < saved.x do fwd() end
  elseif saved.x < 0 then face(2) while pos.x > saved.x do fwd() end end
  face(saved.dir)
end

-------------------------------------------------------------------- SAFE MOVE WRAPPER
local function guardedMove(stepFn)
  -- fuel margin
  if turtle.getFuelLevel() ~= "unlimited" and
     turtle.getFuelLevel() - 1 < distanceHome() + RETURN_MARGIN then
    local save = {x = pos.x, y = pos.y, z = pos.z, dir = dir}
    print("Low fuel → home")
    goHome(); dumpInventory(); ensureFuel(distanceHome() + SAFE_MARGIN)
    resumeFrom(save)
  end
  -- inventory margin
  if isInventoryFull() then
    local save = {x = pos.x, y = pos.y, z = pos.z, dir = dir}
    print("Inventory full → unload")
    goHome(); dumpInventory(); ensureFuel(distanceHome() + SAFE_MARGIN)
    resumeFrom(save)
  end
  stepFn()
end

local function Gfwd()  guardedMove(fwd)  end
local function Gdown() guardedMove(down) end
local function Gup()   guardedMove(up)   end

-------------------------------------------------------------------- PERFECT RECTANGLE SNAKE
local function snakeLayer(len, wid)
  for row = 1, wid do
    -- traverse the row
    for col = 1, len - 1 do
      turtle.dig(); Gfwd()
    end
    turtle.dig()                         -- last block of the row

    -- move to next row if any
    if row < wid then
      if row % 2 == 1 then               -- currently facing +X
        turnRight(); Gfwd(); turnRight()
      else                               -- facing -X
        turnLeft();  Gfwd(); turnLeft()
      end
    end
  end

  -- return to origin X/Z at current Y
  if wid % 2 == 1 then face(2) else face(0) end
  while pos.x ~= 0 do Gfwd() end
  face(3); while pos.z ~= 0 do Gfwd() end
  face(0)
end

-------------------------------------------------------------------- SEGMENTED QUARRY
local function estimateFuel(len, wid, segDepth, startDepth)
  return len * wid * segDepth * FUEL_PER_BLOCK
       + (startDepth + segDepth) * 2
       + SAFE_MARGIN
end

local function mineSegment(len, wid, segDepth)
  for layer = 1, segDepth do
    snakeLayer(len, wid)
    if layer < segDepth then turtle.digDown(); Gdown() end
  end
end

-------------------------------------------------------------------- MAIN
print("Enter length:") local length = tonumber(read())
print("Enter width :" ) local width  = tonumber(read())
print("Enter depth :" ) local depth  = tonumber(read())

-- create 2-block shaft so top 2 horizontal layers stay intact
print("Making 1×1 shaft two blocks deep…")
for _ = 1, 2 do turtle.digDown(); Gdown() end     -- pos.y = -2
depth = depth - 2
if depth <= 0 then
  print("No depth left after skipping top layers.")
  goHome(); return
end

-- split depth into SEGMENTS slices
local base      = math.floor(depth / SEGMENTS)
local segDepths = {base, base, base, base + depth % SEGMENTS}
local currentDepth = 2                             -- already down 2

for seg = 1, SEGMENTS do
  local d = segDepths[seg]
  if d == 0 then break end

  local need = estimateFuel(length, width, d, currentDepth)
  print(("Segment %d: need ≈ %d fuel"):format(seg, need))
  ensureFuel(need)

  print("⛏️  Mining segment "..seg)
  mineSegment(length, width, d)
  currentDepth = currentDepth + d

  -- unload at the end of each slice
  goHome(); dumpInventory()

  -- only resume if more segments remain
  if seg < SEGMENTS and segDepths[seg + 1] > 0 then
    ensureFuel(distanceHome() + SAFE_MARGIN)
    resumeFrom({x = 0, y = -currentDepth, z = 0, dir = 0})
  end
end

goHome(); dumpInventory()
print("✅ Quarry finished – all items deposited, turtle parked at start.")
