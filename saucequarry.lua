-- saucequarry.lua  •  single-drop border, no sky bug (18-Jun-2025)

---------------- CONFIG ----------------
local S = 1                 -- cobble slot
local LOW, TOP = 300, 2000  -- fuel thresholds
local JUNK = { ["minecraft:stone"]=true, ["minecraft:cobbled_deepslate"]=true,
 ["minecraft:dirt"]=true, ["minecraft:andesite"]=true, ["minecraft:granite"]=true,
 ["minecraft:diorite"]=true, ["minecraft:netherrack"]=true, ["minecraft:soul_sand"]=true,
 ["minecraft:soul_soil"]=true, ["minecraft:tuff"]=true }
---------------------------------------

local function dig(d)                      -- d = "f","d","u"
  local ok,dta = (d=="f" and turtle.inspect)
             or (d=="u" and turtle.inspectUp)
             or turtle.inspectDown
  ok,dta = ok(); if not ok or not JUNK[dta.name or ""] then
    if d=="f" then turtle.dig() elseif d=="d" then turtle.digDown()
    else turtle.digUp() end
  end
end
local function cobble()
  turtle.select(S); if turtle.getItemCount()==0 then
    turtle.turnLeft(); for i=1,16 do turtle.select(i); if turtle.suck(64) then break end end
    turtle.turnRight(); turtle.select(S)
  end
end
local function fuel()
  turtle.turnLeft()
  for i=1,16 do if turtle.getItemCount(i)==0 then turtle.select(i); turtle.suck(64) end end
  turtle.turnRight()
  for i=1,16 do
    if turtle.getFuelLevel()>=TOP then break end
    turtle.select(i); while turtle.getItemCount()>0 and turtle.getFuelLevel()<TOP do
      if not turtle.refuel(1) then break end
    end
  end
end
local function dump()
  turtle.turnRight(); turtle.turnRight()
  for i=1,16 do if i~=S then turtle.select(i); turtle.drop() end end
  turtle.turnRight(); turtle.turnRight()
end
----------------------------------------

print("Width :") ;local W = tonumber(read())
print("Length:");local L = tonumber(read())
print("Current Y (e.g. 253):"); local Y=tonumber(read())
local est = math.ceil(W*L*(Y-1)*2.2)
print("\nSupply chest LEFT, dump chest BEHIND")
print("Estimated fuel ≈ "..est..".  Hit <Enter>")
io.read()

cobble(); fuel(); assert(turtle.getFuelLevel()>0,"no fuel")

-- forward one, drop ONE level
dig("f"); turtle.forward()
dig("d"); assert(turtle.down(),"can't drop")

-- draw border one block down
local function mark() turtle.select(S); turtle.placeDown() end
local function corner()
  mark(); turtle.up(); mark(); turtle.down()
end
corner()
for i=1,W-1 do dig("f"); turtle.forward(); mark() end
turtle.turnRight()
for i=1,L-1 do dig("f"); turtle.forward(); mark() end
turtle.turnRight()
for i=1,W-1 do dig("f"); turtle.forward(); mark() end
turtle.turnRight()
for i=1,L-2 do dig("f"); turtle.forward(); mark() end
turtle.turnRight()        -- now at start tile one block down

-- mining helpers
local function col()
  local down=false
  while true do dig("d"); if not turtle.down() then break end
    down=true; dig("f"); dig("u") end
  if down then while turtle.up() do end end
end
local function home(x,z,dir)
  if dir==1 then turtle.turnLeft() elseif dir==3 then turtle.turnRight() end
  for _=1,x do turtle.back() end
  turtle.turnLeft(); turtle.turnLeft()
  for _=1,z do turtle.forward() end
  turtle.turnLeft(); turtle.turnLeft()
end

-- main loop
local x,z,dir=0,0,0
print("Mining…")
while z<L do
  while x<W do
    dig("f"); turtle.forward(); col(); x=x+1
    if turtle.getItemCount(16)>0 or turtle.getFuelLevel()<LOW then
      home(x,z,dir); dump(); fuel(); x,z,dir=0,0,0; print("Resuming…")
    else fuel() end
  end
  if z<L-1 then
    if z%2==0 then turtle.turnRight(); dir=1 else turtle.turnLeft(); dir=3 end
    dig("f"); turtle.forward()
    if z%2==0 then turtle.turnRight(); dir=0 else turtle.turnLeft(); dir=2 end
    x=0; z=z+1
  else z=z+1 end
end
home(x,z,dir); dump()
print("Finished ✓")
