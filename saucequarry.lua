-- saucequarry.lua  •  18-Jun-2025
-- one-chest supply (left), deep-dimension aware, segmented fuel

-------------- CONFIG ----------------
local MARKER_SLOT   = 1              -- cobble for border / corners
local LOW_FUEL      = 300            -- refuel when current < LOW_FUEL
local TOP_UP_FUEL   = 2000           -- try to stay above this
local JUNK = {                       -- blocks we ignore
  ["minecraft:stone"]=true, ["minecraft:cobbled_deepslate"]=true,
  ["minecraft:dirt"]=true,  ["minecraft:andesite"]=true,
  ["minecraft:granite"]=true, ["minecraft:diorite"]=true,
  ["minecraft:netherrack"]=true, ["minecraft:soul_sand"]=true,
  ["minecraft:soul_soil"]=true, ["minecraft:tuff"]=true
}
--------------------------------------

-- helpers ---------------------------------------------------------------
local function inspect(dir)
  local ok,data = (dir=="f" and turtle.inspect)
                 or(dir=="u" and turtle.inspectUp)
                 or turtle.inspectDown
  ok,data = ok()
  return ok and data.name or nil
end
local function shouldDig(name) return not JUNK[name or ""] end
local function digSmart(dir)
  local name = inspect(dir)
  if shouldDig(name) then
    if dir=="f" then turtle.dig()
    elseif dir=="d" then turtle.digDown()
    else turtle.digUp() end
  end
end
local function ensureCobble()
  if inspect("d")=="minecraft:bedrock" then return end -- already got slot1
  -- see if slot1 already cobble
  turtle.select(MARKER_SLOT)
  if turtle.getItemCount()==0 then
    -- pull from left chest
    turtle.turnLeft()
    for i=1,16 do
      if turtle.suck(64) then
        local name = turtle.getItemDetail().name
        if name:find("cobble") then break end
      end
    end
    turtle.turnRight()
  end
end
local function pullFuelItems()
  turtle.turnLeft()
  for i=1,16 do
    if turtle.getItemCount(i)==0 then
      turtle.select(i); turtle.suck(64)
    end
  end
  turtle.turnRight()
end
local function tryRefuel(target)
  -- refuel one item at a time up to target or until no valid fuel left
  for i=1,16 do
    if turtle.getFuelLevel()>=target then return true end
    turtle.select(i)
    while turtle.getItemCount()>0 and turtle.getFuelLevel()<target do
      if turtle.refuel(1)==false then break end -- not fuel, skip stack
    end
  end
  return turtle.getFuelLevel()>=target
end
local function topUpFuel()
  if turtle.getFuelLevel()>=TOP_UP_FUEL then return end
  tryRefuel(TOP_UP_FUEL)
  if turtle.getFuelLevel()<TOP_UP_FUEL then
    -- need more items → go home, dump, grab more
    return false
  end
  return true
end
local function dumpInventory()
  turtle.turnRight(); turtle.turnRight()
  for i=1,16 do if i~=MARKER_SLOT then turtle.select(i); turtle.drop() end end
  turtle.turnRight(); turtle.turnRight()
end
-------------------------------------------------------------------------

---------------- SET-UP PROMPT ------------------------------------------
print("Quarry width?");  local W = tonumber(read())
print("Quarry length?"); local L = tonumber(read())
print("Deep dimension (250-ish deep)? y/n");
local deepAns = read():lower(); local DEPTH = deepAns=="y" and 250 or 64
local estFuel = math.ceil(W*L*DEPTH*2.2)

print("\n=== Setup ===")
print("• Put cobblestone + fuel in chest to the LEFT of turtle")
print("• Put an empty chest directly BEHIND turtle for drops")
print("Estimated total fuel needed ~"..estFuel)
print("Turtle will pull fuel as it goes (20k cap handled).")
print("Hit <Enter> when ready."); io.read()

-------------- INITIAL PREP --------------------------------------------
ensureCobble()
pullFuelItems()
if not tryRefuel(TOP_UP_FUEL) and turtle.getFuelLevel()==0 then
  error("No valid fuel found; aborting.")
end
-------------------------------------------------------------------------

---------------- BORDER MARKING -----------------------------------------
print("Marking border...")
turtle.forward()
local function placeMarker()
  turtle.select(MARKER_SLOT); turtle.placeDown()
end
local function placeCorner()
  turtle.select(MARKER_SLOT); turtle.placeDown(); turtle.up(); turtle.placeDown(); turtle.down()
end
for edge=1,2 do
  local limit = (edge==1) and W or L
  for step=1,limit do
    if step==1 or step==limit then placeCorner() else placeMarker() end
    if step<limit then turtle.forward() end
  end
  turtle.turnRight()
end
for _=1,W-1 do turtle.forward() end; turtle.turnRight()
for _=1,L-1 do turtle.forward() end; turtle.turnRight()
turtle.back() -- return to start block
-------------------------------------------------------------------------

----------------- MAIN MINING LOOP --------------------------------------
local x,z = 0,0     -- our progress counters
local dir = 0       -- 0 east→, 1 south↓, 2 west←, 3 north↑ relative to start
local function gotoHome()
  -- drive back along rows already mined
  while z>0 do
    if dir%2==0 then turtle.turnRight() else turtle.turnLeft() end
    turtle.forward(); if dir%2==0 then turtle.turnRight() else turtle.turnLeft() end
    z=z-1
  end
  while x>0 do turtle.back(); x=x-1 end
end
local function mineColumn()
  while true do
    digSmart("d")
    if not turtle.down() then break end
    digSmart("f"); digSmart("u")
  end
  while turtle.up() do end
end
print("Mining...")
while z<L do
  while x<W do
    -- step
    digSmart("f"); turtle.forward(); mineColumn()
    x = x + 1
    -- fuel / inv checks
    if turtle.getItemCount(16)>0 or turtle.getFuelLevel()<LOW_FUEL then
      gotoHome(); dumpInventory(); pullFuelItems(); topUpFuel(); x,z,dir = 0,0,0
      print("Resuming mining...")
    end
    if not topUpFuel() then gotoHome(); dumpInventory(); pullFuelItems(); topUpFuel() end
  end
  -- row done, shift
  if z < L-1 then
    if (z%2==0) then turtle.turnRight() else turtle.turnLeft() end
    digSmart("f"); turtle.forward()
    if (z%2==0) then turtle.turnRight() else turtle.turnLeft() end
    dir = (dir+1)%4; x=0; z = z + 1
  else
    z = z + 1
  end
end
gotoHome(); dumpInventory()
print("Quarry finished ✓")
