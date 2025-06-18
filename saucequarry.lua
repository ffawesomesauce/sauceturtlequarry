-- saucequarry.lua  •  Based on 0hUKaXKe with border + safe drop

-- === CONFIG ===
local MARKER_SLOT = 1
local LOW_FUEL = 300
local TOP_UP = 2000
local JUNK = {
  ["minecraft:stone"]=true, ["minecraft:cobbled_deepslate"]=true,
  ["minecraft:dirt"]=true, ["minecraft:andesite"]=true,
  ["minecraft:granite"]=true, ["minecraft:diorite"]=true,
  ["minecraft:netherrack"]=true, ["minecraft:soul_sand"]=true,
  ["minecraft:soul_soil"]=true, ["minecraft:tuff"]=true
}

-- === HELPERS ===
local function inspect(dir)
  local ok, data = (dir=="f" and turtle.inspect or dir=="u" and turtle.inspectUp or turtle.inspectDown)()
  return ok and data.name or nil
end

local function digSmart(dir)
  local name = inspect(dir)
  if not JUNK[name or ""] then
    if dir=="f" then turtle.dig()
    elseif dir=="d" then turtle.digDown()
    else turtle.digUp() end
  end
end

local function ensureCobble()
  turtle.select(MARKER_SLOT)
  if turtle.getItemCount() == 0 then
    turtle.turnLeft()
    for i = 1, 16 do
      turtle.select(i)
      if turtle.suck(64) then break end
    end
    turtle.turnRight()
  end
end

local function pullFuel()
  turtle.turnLeft()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then
      turtle.select(i)
      turtle.suck(64)
    end
  end
  turtle.turnRight()
end

local function refuelTo(target)
  for i = 1, 16 do
    if turtle.getFuelLevel() >= target then return true end
    turtle.select(i)
    while turtle.getItemCount() > 0 and turtle.getFuelLevel() < target do
      if not turtle.refuel(1) then break end
    end
  end
  return turtle.getFuelLevel() >= target
end

local function topUpFuel()
  if turtle.getFuelLevel() < TOP_UP then refuelTo(TOP_UP) end
end

local function dumpInventory()
  turtle.turnRight(); turtle.turnRight()
  for i = 1, 16 do
    if i ~= MARKER_SLOT then turtle.select(i); turtle.drop() end
  end
  turtle.turnRight(); turtle.turnRight()
end

-- === SETUP ===
print("Quarry width:")  local W = tonumber(read())
print("Quarry length:") local L = tonumber(read())
print("Current Y height (e.g. 255):") local Y = tonumber(read())
local DEPTH = math.max(1, Y - 1)
local estimatedFuel = math.ceil(W * L * DEPTH * 2.2)

print("\n=== Setup ===")
print("• Supply chest (fuel + cobble) on LEFT")
print("• Output chest BEHIND turtle")
print("Estimated fuel required: " .. estimatedFuel)
print("Press ENTER to continue")
io.read()

ensureCobble()
pullFuel()
if not refuelTo(TOP_UP) then error("No valid fuel found.") end

-- === DROP DOWN ONE BLOCK FOR BORDER ===
digSmart("f"); turtle.forward()
digSmart("d")
assert(turtle.down(), "Failed to move down into quarry area")

-- === MARK BORDER ONE BLOCK DOWN ===
local function mark() turtle.select(MARKER_SLOT); turtle.placeDown() end
local function markCorner()
  turtle.select(MARKER_SLOT)
  turtle.placeDown()
  turtle.up(); turtle.placeDown(); turtle.down()
end

print("Marking border…")
for i = 1, 2 do
  local len = (i == 1) and W or L
  for s = 1, len do
    if s == 1 or s == len then markCorner() else mark() end
    if s < len then digSmart("f"); turtle.forward() end
  end
  turtle.turnRight()
end
for _ = 1, W - 1 do turtle.forward() end
turtle.turnRight()
for _ = 1, L - 1 do turtle.forward() end
turtle.turnRight()
turtle.back()

-- === MINING ===
local x, z = 0, 0
local function goHome()
  while z > 0 do
    turtle.turnLeft(); turtle.turnLeft(); turtle.forward(); turtle.turnLeft(); turtle.turnLeft()
    z = z - 1
  end
  while x > 0 do turtle.back(); x = x - 1 end
end

local function mineColumn()
  local wentDown = false
  while true do
    digSmart("d")
    if not turtle.down() then break end
    wentDown = true
    digSmart("f"); digSmart("u")
  end
  if wentDown then while turtle.up() do end end
end

print("Mining…")
while z < L do
  while x < W do
    digSmart("f"); turtle.forward(); mineColumn(); x = x + 1
    if turtle.getItemCount(16) > 0 or turtle.getFuelLevel() < LOW_FUEL then
      goHome(); dumpInventory(); pullFuel(); topUpFuel(); x, z = 0, 0
      print("Resuming…")
    else
      topUpFuel()
    end
  end
  if z < L - 1 then
    if z % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
    digSmart("f"); turtle.forward()
    if z % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
    x = 0; z = z + 1
  else
    z = z + 1
  end
end

goHome()
dumpInventory()
print("Quarry finished ✓")
