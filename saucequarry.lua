```lua
-- quarry.lua
-- CC:Tweaked Mining Turtle Quarry Script
-- Features:
-- • Filled cobble floor marker (width × length) one block forward from start
-- • 3-block-deep column mining pattern beneath the floor
-- • Supply / fuel chest on turtle’s LEFT, dump chest BEHIND
-- • Mixed-fuel safe (tops up when <300, targets 2 000, 20 000 cap)
-- • Skips common junk blocks, keeps sand & gravel
-- • Auto-return when fuel low or inventory full and resume seamlessly
-- • Never climbs above (startY + 1)
-- • Clear console logs

-------------------------------------------------------------------- UTILITIES --
local junk = {
  ["minecraft:stone"] = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:granite"] = true,
  ["minecraft:diorite"] = true,
  ["minecraft:netherrack"] = true,
  ["minecraft:soul_sand"] = true,
  ["minecraft:soul_soil"] = true,
  ["minecraft:tuff"] = true
}

local function log(txt) print("[Quarry] " .. txt) end

----------------------------------------------------------------- ORIENTATION ----
-- dir: 0 = north, 1 = east, 2 = south, 3 = west
local pos = { x = 0, y = 0, z = 0, dir = 0 }

local function turnLeft()  turtle.turnLeft();  pos.dir = (pos.dir - 1) % 4 end
local function turnRight() turtle.turnRight(); pos.dir = (pos.dir + 1) % 4 end
local function turnAround() turnLeft(); turnLeft() end

local function face(d)
  while pos.dir ~= d do turnRight() end
end

local function fwd()
  while not turtle.forward() do
    turtle.dig()
    sleep(0.1)
  end
  if     pos.dir == 0 then pos.z = pos.z - 1
  elseif pos.dir == 1 then pos.x = pos.x + 1
  elseif pos.dir == 2 then pos.z = pos.z + 1
  else                     pos.x = pos.x - 1 end
end

local function up()
  while not turtle.up() do turtle.digUp(); sleep(0.1) end
  pos.y = pos.y + 1
end

local function down()
  while not turtle.down() do turtle.digDown(); sleep(0.1) end
  pos.y = pos.y - 1
end

-- Move to absolute coordinates, then face dir d
local function goTo(x, y, z, d)
  while pos.y < y do up()   end
  while pos.y > y do down() end
  if pos.x ~= x then
    face((x > pos.x) and 1 or 3)
    for _ = 1, math.abs(x - pos.x) do fwd() end
  end
  if pos.z ~= z then
    face((z > pos.z) and 2 or 0)
    for _ = 1, math.abs(z - pos.z) do fwd() end
  end
  face(d)
end

----------------------------------------------------------------- CHEST I/O ------
-- supply chest is LEFT of ‘home’ facing
-- dump chest is BEHIND ‘home’ facing
local function suckLeft(n)
  turnLeft()
  local ok = turtle.suck(n)
  turnRight()
  return ok
end

local function dropBack()
  turnAround()
  for s = 1, 16 do turtle.select(s); turtle.drop() end
  turnAround()
end

------------------------------------------------------------------ INVENTORY -----
local function haveCobble()
  for s = 1, 16 do
    local i = turtle.getItemDetail(s)
    if i and i.name:find("cobble") then return true end
  end
  return false
end

local function ensureCobble()
  if haveCobble() then return end
  suckLeft()
end

local function isFull()
  for s = 1, 16 do if turtle.getItemCount(s) == 0 then return false end end
  return true
end

-------------------------------------------------------------- FUEL MANAGEMENT ---
local function refuelIfNeeded()
  if turtle.getFuelLevel() >= 300 then return end
  log("Refuelling...")
  for _ = 1, 16 do
    suckLeft()
    for s = 1, 16 do
      turtle.select(s)
      while turtle.refuel(1) do
        if turtle.getFuelLevel() >= 2000 or turtle.getFuelLevel() == turtle.getFuelLimit() then
          return
        end
      end
    end
    if turtle.getFuelLevel() < 300 then
      log("Need more fuel in supply chest!")
      sleep(5)
    end
  end
end

---------------------------------------------------------------- BLOCK FILTER ----
local function shouldDig(info)
  return (not info) or (not junk[info.name])
end

local function digSafe()
  local ok, data = turtle.inspect()
  if shouldDig(ok and data) then turtle.dig() end
end

local function digDownSafe()
  local ok, data = turtle.inspectDown()
  if shouldDig(ok and data) then turtle.digDown() end
end

--------------------------------------------------------------- MINING PATTERN ---
local function mineColumn()
  for _ = 1, 3 do
    digSafe()
    fwd()
    digDownSafe()
    down()
  end
  for _ = 1, 3 do up() end
end

------------------------------------------------------------------ PARAMETERS ----
local W, L, startY

local function prompt()
  io.write("Enter quarry width: " ); W = tonumber(read())
  io.write("Enter quarry length: "); L = tonumber(read())
  io.write("Enter current Y-level: "); startY = tonumber(read())
end

----------------------------------------------------------------- BUILD FLOOR ----
local function placeFloor()
  log("Building cobble floor...")
  ensureCobble()
  fwd()               -- move 1 ahead of start
  local startX, startZ = pos.x, pos.z
  local zig = true

  for z = 1, L do
    for x = 1, W do
      ensureCobble()
      turtle.select(1) -- selection doesn't matter; ensureCobble guarantees cobble somewhere
      -- replace ground with cobble
      digDownSafe()
      turtle.placeDown()
      if x < W then fwd() end
    end
    if z < L then
      if zig then
        turnRight(); fwd(); turnRight()
      else
        turnLeft();  fwd(); turnLeft()
      end
      zig = not zig
    end
  end
  -- move to (0, startY-1, 1) – first column start point one level below floor
  goTo(startX, startY - 1, startZ, 0)
end

----------------------------------------------------------------- MAIN Quarry ----
local function quarry()
  log("Mining begins...")
  local resume = { x = pos.x, y = pos.y, z = pos.z, dir = pos.dir }
  local zig = true
  for z = 1, L do
    for x = 1, W do
      mineColumn()
      if isFull() or turtle.getFuelLevel() < 300 then
        -- remember where we are
        resume.x, resume.y, resume.z, resume.dir = pos.x, pos.y, pos.z, pos.dir
        goTo(0, startY, 0, 0)
        dropBack()
        refuelIfNeeded()
        goTo(resume.x, resume.y, resume.z, resume.dir)
      end
      if x < W then fwd() end
    end
    if z < L then
      if zig then
        turnRight(); fwd(); turnRight()
      else
        turnLeft();  fwd(); turnLeft()
      end
      zig = not zig
    end
  end
  goTo(0, startY, 0, 0)
  dropBack()
  log("Quarry complete.")
end

----------------------------------------------------------------------- RUN ------
prompt()
refuelIfNeeded()
placeFloor()
quarry()
```
