-- quarry_plus_safe_v3.lua
-- Enhanced quarry with:
-- ✅ LEFT-chest fuel & cobble pull
-- ✅ Top-layer fill with cobble
-- ✅ Deletes junk blocks instantly (stone, dirt, etc.)
-- ✅ Safe fuel handling with pause + retry
-- ✅ Safe cobble fill with pause + retry
-- ✅ Breaks out of dig loops on unbreakable blocks
-- ✅ Reduced overhead from fuel checks

--------------------------------------------------------------------------- CONFIG
local FUEL_SLOT        = 16
local COBBLE_NAME      = "minecraft:cobblestone"
local FUEL_CHECK_EVERY = 12
local DIG_RETRY_MAX    = 20
local FUEL_MARGIN_HOME = 10

--------------------------------------------------------------------------- PROMPT
print("Enter length:") local length = tonumber(read())
print("Enter width :" ) local width  = tonumber(read())
print("Enter depth :" ) local depth  = tonumber(read())

--------------------------------------------------------------------------- JUNK
local junkSet = {
  ["minecraft:stone"]             = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:dirt"]              = true,
  ["minecraft:granite"]           = true,
  ["minecraft:diorite"]           = true,
  ["minecraft:netherrack"]        = true,
  ["minecraft:soul_sand"]         = true,
  ["minecraft:soul_soil"]         = true,
  ["minecraft:tuff"]              = true
}

--------------------------------------------------------------------------- STATE
local x, y, z = 0, 0, 0
local dir = 0 -- 0=N,1=E,2=S,3=W
local topFillY, fillDone, moves = nil, false, 0

--------------------------------------------------------------------------- TURN
local function tl() turtle.turnLeft();  dir = (dir - 1) % 4 end
local function tr() turtle.turnRight(); dir = (dir + 1) % 4 end
local function face(d) while dir ~= d do tr() end end
local function turnAround() tr(); tr() end

--------------------------------------------------------------------------- CHEST
local function suckLeft(n)
  tl(); local ok = turtle.suck(n or 1); tr(); return ok
end

--------------------------------------------------------------------------- FUEL
local function manhattan()
  return math.abs(x) + math.abs(y) + math.abs(z)
end

local function itemIsFuel(slot)
  turtle.select(slot)
  return turtle.refuel(0)
end

local function refuel(minNeeded)
  turtle.select(FUEL_SLOT)
  local retryCount = 0

  while turtle.getFuelLevel() < minNeeded do
    if turtle.getItemCount(FUEL_SLOT) == 0 and x == 0 and y == 0 and z == 0 then
      suckLeft(1)
    end
    if turtle.getItemCount(FUEL_SLOT) == 0 or not itemIsFuel(FUEL_SLOT) then
      print("[Quarry] Need at least " .. minNeeded .. " fuel.")
      print("Insert fuel into LEFT chest and press ENTER to retry...")
      io.read()
      retryCount = retryCount + 1
    else
      turtle.refuel(1)
    end
  end
end

local function refuelMaybe()
  moves = moves + 1
  if moves % FUEL_CHECK_EVERY ~= 0 then return end
  local need = manhattan() + FUEL_MARGIN_HOME
  if turtle.getFuelLevel() < need then
    refuel(need + 100)
  end
end

--------------------------------------------------------------------------- COBBLE
local function ensureCobble()
  for s = 1, 15 do
    local d = turtle.getItemDetail(s)
    if d and d.name == COBBLE_NAME then
      turtle.select(s)
      return true
    end
  end

  if x == 0 and y == 0 and z == 0 then
    suckLeft(4)
    for s = 1, 15 do
      local d = turtle.getItemDetail(s)
      if d and d.name == COBBLE_NAME then
        turtle.select(s)
        return true
      end
    end
  end

  -- Prompt user to add cobble
  if y == topFillY then
    print("[Quarry] Out of cobble for top-layer fill.")
    print("Insert cobble into LEFT chest and press ENTER to retry...")
    while true do
      io.read()
      if ensureCobble() then return true end
      print("Still no cobble. Insert more and press ENTER...")
    end
  end

  return false
end

--------------------------------------------------------------------------- JUNK
local function isJunk(name)
  if not name then return false end
  if name == COBBLE_NAME then return fillDone end
  return junkSet[name] or false
end

local function trashJunk()
  for s = 1, 15 do
    local d = turtle.getItemDetail(s)
    if d and isJunk(d.name) then
      turtle.select(s)
      if not turtle.dropDown() then turtle.drop() end
    end
  end
  turtle.select(1)
end

--------------------------------------------------------------------------- DIG
local function digSafe(digFn, detectFn)
  local tries = 0
  while detectFn() and tries < DIG_RETRY_MAX do
    if digFn() then return true end
    tries = tries + 1
    sleep(0.05)
  end
  return tries < DIG_RETRY_MAX
end

--------------------------------------------------------------------------- MOVE
local function placeCobbleBehind()
  turnAround()
  if not turtle.detect() and ensureCobble() then
    turtle.place()
  end
  turnAround()
end

local function fwd()
  refuelMaybe()
  digSafe(turtle.dig, turtle.detect)
  turtle.forward()
  if     dir == 0 then z = z + 1
  elseif dir == 1 then x = x + 1
  elseif dir == 2 then z = z - 1
  else                 x = x - 1 end
  if y == topFillY then placeCobbleBehind() end
  trashJunk()
end

local function down()
  refuelMaybe()
  digSafe(turtle.digDown, turtle.detectDown)
  turtle.down()
  y = y - 1
  if y < topFillY then fillDone = true end
end

--------------------------------------------------------------------------- NAV
local function goto(tx, ty, tz, td)
  while y > ty do down() end -- only dig downward
  if x < tx then face(1); while x < tx do fwd() end
  elseif x > tx then face(3); while x > tx do fwd() end end

  if z < tz then face(0); while z < tz do fwd() end
  elseif z > tz then face(2); while z > tz do fwd() end end

  face(td or 0)
end

--------------------------------------------------------------------------- INVENTORY
local function isFull()
  for i = 1, 15 do if turtle.getItemCount(i) == 0 then return false end end
  return true
end

local function dumpChest()
  local ox, oy, oz, od = x, y, z, dir
  goto(0, 0, 0, 2)
  for i = 1, 15 do turtle.select(i); turtle.drop() end
  turtle.select(1)
  goto(ox, oy, oz, od)
end

--------------------------------------------------------------------------- LAYER
local function mineLayer()
  for row = 1, width do
    for col = 1, length - 1 do
      fwd()
      if isFull() then dumpChest() end
    end
    if row < width then
      if row % 2 == 1 then tr(); fwd(); tr()
      else                 tl(); fwd(); tl() end
    end
  end
  -- reset to NW corner facing north
  if width % 2 == 1 then face(2); for _=1,length-1 do fwd() end end
  face(3); for _=1,width-1 do fwd() end
  face(0)
end

--------------------------------------------------------------------------- MAIN
print("Priming supplies...")
if turtle.getItemCount(FUEL_SLOT) == 0 then suckLeft(16) end
suckLeft(16)
turtle.select(1)

print("Quarry starting...")
digSafe(turtle.digDown, turtle.detectDown)
down()
topFillY = y

for d = 1, depth do
  mineLayer()
  if d < depth then down() end
end

dumpChest()
goto(0, 0, 0, 0)
print("Quarry finished. Top layer filled. Valuables deposited.")
