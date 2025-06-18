-- saucequarry.lua  •  18-Jun-2025  (single-drop border, no sky bug)

------------------------------  CONFIG  ------------------------------
local MARKER_SLOT = 1       -- cobble for border
local LOW_FUEL    = 300     -- refuel trigger
local TOP_UP      = 2000    -- keep fuel above this
local JUNK = {              -- blocks to ignore
  ["minecraft:stone"]=true, ["minecraft:cobbled_deepslate"]=true,
  ["minecraft:dirt"]=true,  ["minecraft:andesite"]=true,
  ["minecraft:granite"]=true, ["minecraft:diorite"]=true,
  ["minecraft:netherrack"]=true, ["minecraft:soul_sand"]=true,
  ["minecraft:soul_soil"]=true, ["minecraft:tuff"]=true
}
---------------------------------------------------------------------

-----------------------------  HELPERS  -----------------------------
local function inspect(dir)
  local ok,data = (dir=="f" and turtle.inspect)
                or(dir=="u" and turtle.inspectUp)
                or turtle.inspectDown
  ok,data = ok(); return ok and data.name or nil
end
local function dig(dir)
  local n = inspect(dir); if not JUNK[n or ""] then
    if dir=="f" then turtle.dig()
    elseif dir=="d" then turtle.digDown()
    else turtle.digUp() end
  end
end
local function ensureCobble()
  turtle.select(MARKER_SLOT)
  if turtle.getItemCount()==0 then
    turtle.turnLeft()
    for i=1,16 do turtle.select(i); if turtle.suck(64) then break end end
    turtle.turnRight()
  end
end
local function pullFuel()
  turtle.turnLeft()
  for i=1,16 do
    if turtle.getItemCount(i)==0 then turtle.select(i); turtle.suck(64) end
  end
  turtle.turnRight()
end
local function refuelTo(n)
  for i=1,16 do
    if turtle.getFuelLevel()>=n then return true end
    turtle.select(i)
    while turtle.getItemCount()>0 and turtle.getFuelLevel()<n do
      if not turtle.refuel(1) then break end
    end
  end
  return turtle.getFuelLevel()>=n
end
local function topUp() if turtle.getFuelLevel()<TOP_UP then refuelTo(TOP_UP) end end
local function dumpInv()
  turtle.turnRight(); turtle.turnRight()
  for i=1,16 do if i~=MARKER_SLOT then turtle.select(i); turtle.drop() end end
  turtle.turnRight(); turtle.turnRight()
end
---------------------------------------------------------------------

-------------------------  USER PROMPTS  ----------------------------
print("Quarry width :")  local W = tonumber(read())
print("Quarry length:")  local L = tonumber(read())
print("Current Y (e.g. 253):") local Y = tonumber(read())
local DEPTH = math.max(1, Y-1)
local estFuel = math.ceil(W*L*DEPTH*2.2)

print("\n=== Setup ===")
print("• Supply chest (fuel + cobble) LEFT of turtle")
print("• Output chest BEHIND turtle")
print("Estimated fuel needed ≈ "..estFuel)
print("Press <Enter> when ready"); io.read()

---------------------------  PREP  ----------------------------------
ensureCobble(); pullFuel()
assert(refuelTo(TOP_UP), "No valid fuel found")

-----------------------  DROP 1 BLOCK  ------------------------------
dig("f"); turtle.forward()
dig("d"); assert(turtle.down(), "Couldn't drop to quarry level")

---------------------  BORDER MARKING  ------------------------------
local function mark() turtle.select(MARKER_SLOT); turtle.placeDown() end
local function corner()
  turtle.select(MARKER_SLOT); turtle.placeDown()   -- lower block
  turtle.up(); turtle.placeDown(); turtle.down()   -- upper block
end

print("Marking border…")
local startDir = 0         -- 0 = forward
local dx, dz = 0, 0        -- track position relative to drop point

local function fwd()
  dig("f"); turtle.forward()
  if startDir==0 then dx=dx+1
  elseif startDir==1 then dz=dz+1
  elseif startDir==2 then dx=dx-1
  else dz=dz-1 end
end
local function turnR() startDir=(startDir+1)%4; turtle.turnRight() end

for edge=1,2 do
  local len=(edge==1) and W or L
  for s=1,len do
    if s==1 or s==len then corner() else mark() end
    if s<len then fwd() end
  end
  turnR()
end
for _=1,W-1 do fwd() end; turnR()
for _=1,L-1 do fwd() end; turnR()

-- back to drop point on lower level
while dx>0 do turtle.back(); dx=dx-1 end
while dx<0 do dig("f"); turtle.forward(); dx=dx+1 end
while dz>0 do turtle.turnLeft(); dig("f"); turtle.forward(); turtle.turnRight(); dz=dz-1 end
while dz<0 do turtle.turnLeft(); turtle.turnLeft(); dig("f"); turtle.forward(); turtle.turnLeft(); turtle.turnLeft(); dz=dz+1 end
-- turtle now exactly one block down, ready to mine

---------------------  MINING FUNCTIONS  ---------------------------
local x,z,dir = 0,0,0
local function home()
  while z>0 do
    if dir%2==0 then turtle.turnRight() else turtle.turnLeft() end
    turtle.forward()
    if dir%2==0 then turtle.turnRight() else turtle.turnLeft() end
    z=z-1
  end
  while x>0 do turtle.back(); x=x-1 end
end
local function mineColumn()
  local wentDown=false
  while true do
    dig("d"); if not turtle.down() then break end
    wentDown=true; dig("f"); dig("u")
  end
  if wentDown then while turtle.up() do end end
end
---------------------------------------------------------------------

--------------------------  MINING  ---------------------------------
print("Mining…")
while z<L do
  while x<W do
    dig("f"); turtle.forward(); mineColumn(); x=x+1
    if turtle.getItemCount(16)>0 or turtle.getFuelLevel()<LOW_FUEL then
      home(); dumpInv(); pullFuel(); topUp(); x,z,dir=0,0,0; print("Resuming…")
    else topUp() end
  end
  if z<L-1 then
    if z%2==0 then turtle.turnRight() else turtle.turnLeft() end
    dig("f"); turtle.forward()
    if z%2==0 then turtle.turnRight() else turtle.turnLeft() end
    x=0; z=z+1; dir=(dir+1)%4
  else z=z+1 end
end
home(); dumpInv()
print("Quarry complete ✓")
