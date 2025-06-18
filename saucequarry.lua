-- quarry_plus_run4_with_autounload.lua
-- Smart turtle quarry with segmented mining and auto-unload

-------------------------------------------------------------------- CONFIG
local FUEL_SLOT        = 16
local SEGMENTS         = 4
local FUEL_PER_ITEM    = 80       -- assumed fuel per item (coal)
local FUEL_PER_BLOCK   = 3
local SAFE_MARGIN      = 40
local RETURN_MARGIN    = 15
local DIG_RETRY_MAX    = 20

-------------------------------------------------------------------- STATE
local pos = {x = 0, y = 0, z = 0}
local dir = 0   -- 0:+X 1:+Z 2:-X 3:-Z

-------------------------------------------------------------------- NAV HELPERS
local function face(d) while dir ~= d do turtle.turnRight(); dir = (dir+1)%4 end end
local function turnLeft()  turtle.turnLeft(); dir = (dir+3)%4 end
local function turnRight() turtle.turnRight(); dir = (dir+1)%4 end
local function fwd()
  for i=1,DIG_RETRY_MAX do
    if turtle.forward() then
      if     dir==0 then pos.x=pos.x+1
      elseif dir==1 then pos.z=pos.z+1
      elseif dir==2 then pos.x=pos.x-1
      else               pos.z=pos.z-1 end
      return true
    end
    turtle.dig(); turtle.attack(); sleep(0.2)
  end
  error("Block ahead is unbreakable – abort")
end
local function up()
  for i=1,DIG_RETRY_MAX do if turtle.up() then pos.y=pos.y+1 return true end
    turtle.digUp(); turtle.attackUp(); sleep(0.2) end
  error("Block above unbreakable")
end
local function down()
  for i=1,DIG_RETRY_MAX do if turtle.down() then pos.y=pos.y-1 return true end
    turtle.digDown(); turtle.attackDown(); sleep(0.2) end
  error("Block below unbreakable")
end
local function distanceHome() return math.abs(pos.x)+math.abs(pos.y)+math.abs(pos.z) end

-------------------------------------------------------------------- FUEL
local function ensureFuel(minimum)
  if turtle.getFuelLevel()=="unlimited" then return end
  local startDir = dir
  face((startDir+3)%4)                     -- look left (fuel chest)
  turtle.select(FUEL_SLOT)
  while turtle.getFuelLevel() < minimum do
    if not turtle.suck(1) then
      print("Waiting for fuel… need "..(minimum - turtle.getFuelLevel()))
      sleep(10)
    else
      turtle.refuel()
    end
  end
  face(startDir); turtle.select(1)
end

-------------------------------------------------------------------- INVENTORY MANAGEMENT
local function isInventoryFull()
  for s=1,15 do
    if turtle.getItemCount(s) == 0 then return false end
  end
  return true
end

local function dumpInventory()
  turtle.select(1)
  turnLeft(); turnLeft()          -- face rear chest
  for s=1,15 do
    if s~=FUEL_SLOT and turtle.getItemCount(s)>0 then
      turtle.select(s); turtle.drop()
    end
  end
  turtle.select(1)
  turnLeft(); turnLeft()          -- face forward again
end

-------------------------------------------------------------------- GO HOME
local function goHome()
  while pos.y<0 do up()  end
  while pos.y>0 do down() end
  if pos.z>0 then face(3) while pos.z>0 do fwd() end
  elseif pos.z<0 then face(1) while pos.z<0 do fwd() end end
  if pos.x>0 then face(2) while pos.x>0 do fwd() end
  elseif pos.x<0 then face(0) while pos.x<0 do fwd() end end
  face(0)
end

-------------------------------------------------------------------- GUARDED MOVE
local function guardedMove(stepFn)
  if turtle.getFuelLevel() ~= "unlimited" then
    if turtle.getFuelLevel() - 1 < distanceHome() + RETURN_MARGIN then
      print("Low fuel – heading home")
      local save = {x=pos.x,y=pos.y,z=pos.z,dir=dir}
      goHome(); dumpInventory()
      ensureFuel(distanceHome()+SAFE_MARGIN)
      pos = save; dir = save.dir; print("Resuming dig")
    end
  end

  if isInventoryFull() then
    print("Inventory full – returning to unload")
    local save = {x=pos.x,y=pos.y,z=pos.z,dir=dir}
    goHome(); dumpInventory()
    ensureFuel(distanceHome()+SAFE_MARGIN)
    pos = save; dir = save.dir; print("Resuming dig")
  end

  stepFn()
end
local function Gfwd()  guardedMove(fwd)  end
local function Gdown() guardedMove(down) end
local function Gup()   guardedMove(up)   end

-------------------------------------------------------------------- QUARRY ROUTINES
local function snakeLayer(len,wid)
  for row=1,wid do
    for step=1,(row==wid and len-1 or len) do turtle.dig(); Gfwd() end
    if row<wid then
      if row%2==1 then turnRight(); turtle.dig(); Gfwd(); turnRight()
      else             turnLeft();  turtle.dig(); Gfwd(); turnLeft()  end
    end
  end
  if wid%2==1 then face(2) else face(0) end
  while pos.x~=0 do Gfwd() end
  face(3); while pos.z~=0 do Gfwd() end
  face(0)
end

local function estimateFuel(len,wid,segDepth,startDepth)
  return len*wid*segDepth*FUEL_PER_BLOCK + (startDepth + segDepth)*2 + SAFE_MARGIN
end

local function mineSegment(len,wid,segDepth)
  for lyr=1,segDepth do
    snakeLayer(len,wid)
    if lyr<segDepth then turtle.digDown(); Gdown() end
  end
end

-------------------------------------------------------------------- MAIN
print("Enter length:") local length = tonumber(read())
print("Enter width :" ) local width  = tonumber(read())
print("Enter depth :" ) local depth  = tonumber(read())

local base = math.floor(depth/SEGMENTS)
local segDepths = {base,base,base,base + (depth % SEGMENTS)}

local currentDepth = 0
for seg=1,SEGMENTS do
  local d = segDepths[seg]
  if d==0 then break end
  local needed = estimateFuel(length,width,d,currentDepth)
  print(("Run %d: fuel estimate %d"):format(seg, needed))
  ensureFuel(needed)
  print("Digging segment "..seg)
  mineSegment(length,width,d)
  currentDepth = currentDepth + d
  goHome(); dumpInventory()
end
print("✅  Quarry complete")
