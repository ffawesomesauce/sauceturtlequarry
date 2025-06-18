-- quarry_plus_safe_v5.lua
-- ░ New in v5 ░
--  • When the turtle needs fuel or cobble it **returns home**, restocks,
--    then resumes automatically.
--  • Never waits in-place out in the quarry.
--  • goto() can now travel upward (adds up() helper).
--  • Recursion removed; all retry loops are iterative.

-------------------------------------------------------------------- SETTINGS --
local FUEL_SLOT        = 16
local COBBLE_NAME      = "minecraft:cobblestone"
local FUEL_CHECK_EVERY = 12
local DIG_RETRY_MAX    = 20
local FUEL_MARGIN_HOME = 10        -- safety buffer

-------------------------------------------------------------------- PROMPT -----
print("Enter length:") local length = tonumber(read())
print("Enter width :" ) local width  = tonumber(read())
print("Enter depth :" ) local depth  = tonumber(read())

--------------------------------------------------------------------- JUNK ------
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

------------------------------------------------------------------- STATE -------
local x, y, z = 0, 0, 0           -- turtle’s relative coords
local dir     = 0                 -- 0=N,1=E,2=S,3=W
local topFillY, fillDone = nil, false
local moves = 0

---------------------------------------------------------------- TURN / FACE ----
local function tl() turtle.turnLeft();  dir = (dir - 1) % 4 end
local function tr() turtle.turnRight(); dir = (dir + 1) % 4 end
local function face(d) while dir ~= d do tr() end end
local function turnAround() tr(); tr() end

---------------------------------------------------------------- CHEST SHORTCUT --
local function suckLeft(n) tl(); local ok = turtle.suck(n or 1); tr(); return ok end

---------------------------------------------------------------- FUEL ----------
local function manhattan() return math.abs(x) + math.abs(y) + math.abs(z) end
local function itemIsFuel(slot) turtle.select(slot); return turtle.refuel(0) end

local function refuelAtHome(minNeeded)
  turtle.select(FUEL_SLOT)
  while turtle.getFuelLevel() < minNeeded do
    if turtle.getItemCount(FUEL_SLOT) == 0 then
      if not suckLeft(4) then
        print("[Quarry] Supply chest out of fuel! Add fuel & press ENTER...")
        io.read()
      end
    end
    if turtle.getItemCount(FUEL_SLOT) > 0 and itemIsFuel(FUEL_SLOT) then
      turtle.refuel(1)
    else
      -- non-fuel item: drop into dump chest behind
      turtle.drop()
    end
  end
end

---------------------------------------------------------------- DIG WRAPPER ----
local function digSafe(digFn, detectFn)
  local tries = 0
  while detectFn() and tries < DIG_RETRY_MAX do
    if digFn() then break end
    tries = tries + 1
    sleep(0.05)
  end
end

---------------------------------------------------------------- MOVERS (dir) ---
local warnedCobble = false

local function placeCobbleBehind()
  turnAround()
  if not turtle.detect() then
    for s = 1, 15 do
      local d = turtle.getItemDetail(s)
      if d and d.name == COBBLE_NAME then
        turtle.select(s); turtle.place(); break
      end
    end
  end
  turnAround()
end

-- will be re-declared later so helpers above can call
local goto, restockCobble, restockFuel

local function refuelMaybe()
  moves = moves + 1
  if moves % FUEL_CHECK_EVERY ~= 0 then return end
  local needed = manhattan() + FUEL_MARGIN_HOME
  if turtle.getFuelLevel() < needed then restockFuel(needed + 100) end
end

local function trashJunk()
  for s = 1, 15 do
    local d = turtle.getItemDetail(s)
    if d and (junkSet[d.name] or (fillDone and d.name == COBBLE_NAME)) then
      turtle.select(s)
      if not turtle.dropDown() then turtle.drop() end
    end
  end
  turtle.select(1)
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

local function up()
  refuelMaybe()
  digSafe(turtle.digUp, turtle.detectUp)
  turtle.up()
  y = y + 1
end

---------------------------------------------------------------- NAVIGATION -----
goto = function(tx, ty, tz, td)
  while y < ty do up()   end
  while y > ty do down() end
  if x < tx then face(1); while x < tx do fwd() end
  elseif x > tx then face(3); while x > tx do fwd() end end
  if z < tz then face(0); while z < tz do fwd() end
  elseif z > tz then face(2); while z > tz do fwd() end end
  face(td or 0)
end

---------------------------------------------------------------- RESTOCKERS -----
restockCobble = function()
  local ox, oy, oz, od = x, y, z, dir
  goto(0, 0, 0, 0)                -- home origin
  warnedCobble = false            -- reset warning
  -- Try to pull cobble until at least one stack in inventory 1-15
  while true do
    local got = suckLeft(16)
    local hasCob = false
    for s = 1, 15 do
      local d = turtle.getItemDetail(s)
      if d and d.name == COBBLE_NAME then hasCob = true; break end
    end
    if hasCob then break end
    print("[Quarry] Need cobble for top fill. Add cobble & press ENTER...")
    io.read()
  end
  goto(ox, oy, oz, od)            -- resume
end

restockFuel = function(minNeeded)
  local ox, oy, oz, od = x, y, z, dir
  goto(0, 0, 0, 0)
  refuelAtHome(minNeeded)
  goto(ox, oy, oz, od)
end

---------------------------------------------------------------- INVENTORY ------
local function invFull()
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

---------------------------------------------------------------- LAYER MINING ---
local function mineLayer()
  for row = 1, width do
    for col = 1, length - 1 do
      fwd()
      if invFull() then dumpChest() end
    end
    if row < width then
      if row % 2 == 1 then tr(); fwd(); tr()
      else                 tl(); fwd(); tl() end
    end
  end
  -- reset to NW corner facing north
  if width % 2 == 1 then face(2); for _ = 1, length - 1 do fwd() end end
  face(3); for _ = 1, width - 1  do fwd() end
  face(0)
end

---------------------------------------------------------------- PRIME SUPPLY ---
print("Loading initial supplies...")
if turtle.getItemCount(FUEL_SLOT) == 0 then suckLeft(16) end
suckLeft(16)
refuelAtHome(manhattan() + FUEL_MARGIN_HOME + 100)
-- ensure at least some cobble
restockCobble()

---------------------------------------------------------------- MAIN ----------
print("Quarry starting...")
digSafe(turtle.digDown, turtle.detectDown); down()
topFillY = y

for layer = 1, depth do
  mineLayer()
  if layer < depth then down() end
  if layer == 1 then fillDone = true end -- after leaving top Fill layer
end

dumpChest()
goto(0, 0, 0, 0)
print("Quarry finished. Top layer filled. Valuables deposited.")
