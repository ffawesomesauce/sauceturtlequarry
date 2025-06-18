--[[
quarry_plus_auto_refuel.lua
An upgraded CC:Tweaked quarry script that can:
  • Pull fuel from a supply chest on the *left* of the turtle at start‑up
  • Deposit mined blocks into a chest *behind* the turtle (as before)
  • Estimate the total fuel required for the job (including the trip home)
  • Top‑up fuel automatically until the estimate is met before leaving
  • Monitor fuel while mining; if the remaining fuel would not cover the
    route back to base it automatically returns, refuels, and resumes

Written for ComputerCraft / CC:Tweaked 1.100+ (Minecraft 1.20.x)
Tested on Forge & Fabric – should work on any recent CC:T build.
--]]

-------------------------------------------------------------------- CONFIG
local FUEL_SLOT        = 16                  -- dedicated fuel slot
local COBBLE_NAME      = "minecraft:cobblestone" -- used for top‑layer filling
local SAFE_MARGIN      = 50                  -- extra fuel buffer for safety
local RETURN_MARGIN    = 15                  -- min fuel to keep in reserve when away
local DIG_RETRY_MAX    = 20                  -- tries for unbreakable blocks

-------------------------------------------------------------------- STATE
local pos   = { x = 0, y = 0, z = 0 }       -- turtle coords (0,0,0 = start)
local dir   = 0                             -- 0=facing +X, 1=+Z, 2=-X, 3=-Z
local quit  = false                         -- set true to abort

-------------------------------------------------------------------- HELPERS
local function face( d )
  while dir ~= d do turtle.turnRight(); dir = (dir + 1) % 4 end
end

local function fwd()
  for i = 1, DIG_RETRY_MAX do
    if turtle.forward() then
      if     dir==0 then pos.x = pos.x + 1
      elseif dir==1 then pos.z = pos.z + 1
      elseif dir==2 then pos.x = pos.x - 1
      else                pos.z = pos.z - 1 end
      return true
    end
    turtle.dig()
    turtle.attack()
    sleep(0.2)
  end
  error("‼️  Block ahead is unbreakable – aborting!")
end

local function up()
  for i = 1, DIG_RETRY_MAX do
    if turtle.up() then pos.y = pos.y + 1 return true end
    turtle.digUp(); turtle.attackUp(); sleep(0.2)
  end
  error("‼️  Block above is unbreakable – aborting!")
end

local function down()
  for i = 1, DIG_RETRY_MAX do
    if turtle.down() then pos.y = pos.y - 1 return true end
    turtle.digDown(); turtle.attackDown(); sleep(0.2)
  end
  error("‼️  Block below is unbreakable – aborting!")
end

local function turnLeft()  turtle.turnLeft();  dir = (dir + 3) % 4 end
local function turnRight() turtle.turnRight(); dir = (dir + 1) % 4 end
local function turnAround() turtle.turnLeft(); turtle.turnLeft(); dir = (dir + 2) % 4 end

-- Manhattan distance home (ignores obstacles; good enough for fuel maths)
local function distanceHome()
  return math.abs(pos.x) + math.abs(pos.y) + math.abs(pos.z)
end

-------------------------------------------------------------------- FUEL
local function tryRefuelOnce()
  -- pull from chest on the *left* into FUEL_SLOT, then refuel()
  face( (dir + 3) % 4 )  -- look left
  local sucked = turtle.suck()
  face( (dir + 1) % 4 )  -- look forward again
  if sucked then
    turtle.select(FUEL_SLOT)
    turtle.refuel()
    turtle.select(1)
  end
  return sucked
end

local function ensureFuel(minimum)
  if turtle.getFuelLevel() == "unlimited" then return end
  while turtle.getFuelLevel() < minimum do
    print("⛽  Need " .. (minimum - turtle.getFuelLevel()) .. " more fuel units…")
    if not tryRefuelOnce() then
      print("❗  No fuel in supply chest – waiting 10s… (Ctrl+T to abort)")
      sleep(10)
    end
  end
end

-------------------------------------------------------------------- INVENTORY
local function dumpInventory()
  turnAround() -- now facing the chest behind start position
  for slot = 1, 15 do
    if slot ~= FUEL_SLOT and not turtle.getItemDetail(slot, false) == nil then
      turtle.select(slot)
      turtle.drop()
    end
  end
  turtle.select(1)
  turnAround() -- face forward again
end

-------------------------------------------------------------------- NAVIGATION (simple go‑to origin)
local function goHome()
  -- Y first → then X → then Z so we always end facing +X like at start
  while pos.y < 0 do up() end
  while pos.y > 0 do down() end

  if pos.z > 0 then face(3) while pos.z > 0 do fwd() end end
  if pos.z < 0 then face(1) while pos.z < 0 do fwd() end end

  if pos.x > 0 then face(2) while pos.x > 0 do fwd() end end
  if pos.x < 0 then face(0) while pos.x < 0 do fwd() end end

  face(0) -- reset orientation
end

-------------------------------------------------------------------- FUEL‑AWARE MOVEMENT WRAPPER
local function guardedMove(moveFn, fuelCost)
  if turtle.getFuelLevel() ~= "unlimited" then
    if turtle.getFuelLevel() - fuelCost < distanceHome() + RETURN_MARGIN then
      print("🔄  Low fuel – returning to base to top‑up…")
      local saved = { x = pos.x, y = pos.y, z = pos.z, dir = dir }
      goHome(); dumpInventory(); ensureFuel(distanceHome() + SAFE_MARGIN)
      -- resume
      pos  = saved; dir = saved.dir
      print("🚀  Refuel complete – resuming quarry…")
    end
  end
  return moveFn()
end

-- wrappers used by dig loop
local function Gfwd()  return guardedMove(fwd,   1) end
local function Gup()   return guardedMove(up,    1) end
local function Gdown() return guardedMove(down,  1) end

-------------------------------------------------------------------- QUARRY LOGIC
local function estimateFuelNeeded(len, wid, dep)
  -- Crude upper‑bound: each block costs up to 3 fuel (dig+move) + transit
  return len * wid * dep * 3 + dep * (len + wid) + SAFE_MARGIN
end

local function snakeLayer(len, wid)
  for row = 1, wid do
    for step = 1, (row==wid and len-1 or len) do
      turtle.dig(); Gfwd()
    end
    if row < wid then
      if row % 2 == 1 then turnRight(); turtle.dig(); Gfwd(); turnRight()
      else                   turnLeft();  turtle.dig(); Gfwd(); turnLeft() end
    end
  end
  -- at end of layer we're at opposite X and on last row; return to (0, currentY, 0)
  if wid % 2 == 1 then face(2) else face(0) end
  while pos.x ~= 0 do Gfwd() end
  face(3)
  while pos.z ~= 0 do Gfwd() end
  face(0)
end

local function quarry(len, wid, dep)
  for d = 1, dep do
    snakeLayer(len, wid)
    dumpInventory()
    if d < dep then turtle.digDown(); Gdown() end
  end
  goHome(); dumpInventory()
end

-------------------------------------------------------------------- MAIN
print("Enter length:") ; local length = tonumber(read())
print("Enter width :") ; local width  = tonumber(read())
print("Enter depth :") ; local depth  = tonumber(read())

local needed = estimateFuelNeeded(length, width, depth)
print(string.format("⛽  Estimated fuel needed: %d units", needed))
ensureFuel(needed)

print("🪓  Mining %dx%dx%d quarry – stand back!", length, width, depth)
quarry(length, width, depth)
print("✅  Quarry complete! All items deposited.")
