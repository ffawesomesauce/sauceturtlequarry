-- saucequarry.lua  •  Border is now placed one block down, corners stack to turtle height

-------------- CONFIG ----------------
local MARKER_SLOT = 1
local LOW_FUEL = 300
local TOP_UP_FUEL = 2000
local JUNK = {
  ["minecraft:stone"]=true, ["minecraft:cobbled_deepslate"]=true,
  ["minecraft:dirt"]=true,  ["minecraft:andesite"]=true,
  ["minecraft:granite"]=true, ["minecraft:diorite"]=true,
  ["minecraft:netherrack"]=true, ["minecraft:soul_sand"]=true,
  ["minecraft:soul_soil"]=true, ["minecraft:tuff"]=true
}
--------------------------------------

-- utility functions
local function inspect(dir)
  local ok, d = (dir == "f" and turtle.inspect) or
                (dir == "u" and turtle.inspectUp) or
                turtle.inspectDown
  ok, d = ok()
  return ok and d.name or nil
end

local function shouldDig(name) return not JUNK[name or ""] end

local function digSmart(dir)
  local n = inspect(dir)
  if shouldDig(n) then
    if dir == "f" then turtle.dig()
    elseif dir == "d" then turtle.digDown()
    else turtle.digUp() end
  end
end

local function ensureCobble()
  turtle.select(MARKER_SLOT)
  if turtle.getItemCount() == 0 then
    turtle.turnLeft()
    for i = 1, 16 do
      if turtle.suck(64) then
        local itm = turtle.getItemDetail()
        if itm and itm.name:find("cobble") then break end
      end
    end
    turtle.turnRight()
  end
end

local function pullFuel()
  turtle.turnLeft()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then turtle.select(i); turtle.suck(64) end
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

local function topUp() if turtle.getFuelLevel() < TOP_UP_FUEL then refuelTo(TOP_UP_FUEL) end end

local function dumpInv()
  turtle.turnRight(); turtle.turnRight()
  for i = 1, 16 do if i ~= MARKER_SLOT then turtle.select(i); turtle.drop() end end
  turtle.turnRight(); turtle.turnRight()
end

-- input
print("Quarry width:")  ; local W = tonumber(read())
print("Quarry length:") ; local L = tonumber(read())
print("Current Y height (e.g. 255):")
local startY = tonumber(read())
local DEPTH = math.max(1, startY - 1)
local estFuel = math.ceil(W * L * DEPTH * 2.2)

print("\n=== Setup ===")
print("• Supply chest (cobble + fuel) on LEFT of turtle")
print("• Output chest BEHIND turtle")
print("Estimated total fuel ~" .. estFuel)
print("Press Enter when ready."); io.read()

ensureCobble()
pullFuel()
if not refuelTo(TOP_UP_FUEL) then error("No valid fuel found.") end

-- drop 1 block to begin
digSmart("d")
local dropped = turtle.down()

-- border marking, 1 block lower
print("Marking border...")
digSmart("f")
turtle.forward()
digSmart("d")
if not turtle.down() then error("Couldn't drop for border marking") end

local function placeMarker()
  turtle.select(MARKER_SLOT)
  turtle.placeDown()
end

local function placeCornerPillar()
  -- lower block
  turtle.select(MARKER_SLOT)
  turtle.placeDown()
  -- upper block at turtle’s starting height
  turtle.up()
  turtle.placeDown()
  turtle.down()
end

for edge = 1, 2 do
  local limit = (edge == 1) and W or L
  for s = 1, limit do
    if s == 1 or s == limit then placeCornerPillar() else placeMarker() end
    if s < limit then digSmart("f"); turtle.forward() end
  end
  turtle.turnRight()
end

for _ = 1, W - 1 do turtle.forward() end
turtle.turnRight()
for _ = 1, L - 1 do turtle.forward() end
turtle.turnRight()
turtle.back()
turtle.up()  -- return to turtle Y level

-- mining
local x, z, dir = 0, 0, 0
local function home()
  while z > 0 do
    if dir % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
    turtle.forward()
    if dir % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
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

print("Mining...")
while z < L do
  while x < W do
    digSmart("f"); turtle.forward(); mineColumn(); x = x + 1
    if turtle.getItemCount(16) > 0 or turtle.getFuelLevel() < LOW_FUEL then
      home(); dumpInv(); pullFuel(); topUp(); x, z, dir = 0, 0, 0
      print("Resuming…")
    else
      topUp()
    end
  end
  if z < L - 1 then
    if z % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
    digSmart("f"); turtle.forward()
    if z % 2 == 0 then turtle.turnRight() else turtle.turnLeft() end
    dir = (dir + 1) % 4; x = 0; z = z + 1
  else
    z = z + 1
  end
end

home(); dumpInv()
print("Quarry finished ✓")
