-- quarry.lua
-- CC:Tweaked Turtle Quarry Script (Filled Floor, 3-Block Mining, Auto Resume)

-- === CONFIG ===
local junkBlocks = {
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

-- === STATE ===
local width, length, startY
local home = { x = 0, y = 0, z = 0, dir = 0 }
local pos = { x = 0, y = 0, z = 0 }
local dir = 0 -- 0=N, 1=E, 2=S, 3=W

-- === HELPERS ===
local function log(msg)
  print("[Quarry] " .. msg)
end

local function turnLeft()
  turtle.turnLeft()
  dir = (dir - 1) % 4
end

local function turnRight()
  turtle.turnRight()
  dir = (dir + 1) % 4
end

local function face(d)
  while dir ~= d do
    turnRight()
  end
end

local function moveForward()
  while not turtle.forward() do
    turtle.dig()
    sleep(0.1)
  end
  if dir == 0 then pos.z = pos.z - 1
  elseif dir == 1 then pos.x = pos.x + 1
  elseif dir == 2 then pos.z = pos.z + 1
  elseif dir == 3 then pos.x = pos.x - 1 end
end

local function moveUp()
  while not turtle.up() do
    turtle.digUp()
    sleep(0.1)
  end
  pos.y = pos.y + 1
end

local function moveDown()
  while not turtle.down() do
    turtle.digDown()
    sleep(0.1)
  end
  pos.y = pos.y - 1
end

local function goTo(x, y, z, faceDir)
  while pos.y < y do moveUp() end
  while pos.y > y do moveDown() end

  local dx = x - pos.x
  if dx ~= 0 then
    face((dx > 0) and 1 or 3)
    for _ = 1, math.abs(dx) do moveForward() end
  end

  local dz = z - pos.z
  if dz ~= 0 then
    face((dz > 0) and 2 or 0)
    for _ = 1, math.abs(dz) do moveForward() end
  end

  face(faceDir)
end

-- === CORE FEATURES ===
local function isJunk(name)
  return junkBlocks[name] or false
end

local function digIfWorth()
  local ok, data = turtle.inspect()
  if not ok or not isJunk(data.name) then turtle.dig() end
end

local function digDownIfWorth()
  local ok, data = turtle.inspectDown()
  if not ok or not isJunk(data.name) then turtle.digDown() end
end

local function isFull()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then return false end
  end
  return true
end

local function refuelIfNeeded()
  if turtle.getFuelLevel() >= 300 then return end
  log("Refueling...")
  for i = 1, 16 do
    turtle.select(i)
    turtle.suck("left")
    while turtle.refuel(1) do
      if turtle.getFuelLevel() >= 2000 then return end
    end
  end
end

local function dumpAll()
  log("Dumping items...")
  for i = 1, 16 do
    turtle.select(i)
    turtle.drop("back")
  end
end

local function placeCobble()
  for i = 1, 16 do
    local item = turtle.getItemDetail(i)
    if item and item.name:find("cobble") then
      turtle.select(i)
      if turtle.placeDown() then return true end
    end
  end
  return false
end

-- === INITIAL PROMPT ===
local function prompt()
  io.write("Enter quarry width: ") width = tonumber(read())
  io.write("Enter quarry length: ") length = tonumber(read())
  io.write("Enter current Y-level: ") startY = tonumber(read())
end

-- === FLOOR LAYERING ===
local function drawFilledCobbleFloor()
  log("Placing cobble floor...")
  moveForward() -- step 1 forward
  moveDown()

  local sx, sy, sz = pos.x, pos.y, pos.z
  local zig = true

  for z = 1, length do
    for x = 1, width do
      placeCobble()
      if x < width then moveForward() end
    end
    if z < length then
      if zig then
        turnRight()
        moveForward()
        turnRight()
      else
        turnLeft()
        moveForward()
        turnLeft()
      end
      zig = not zig
    end
  end

  goTo(sx, sy - 1, sz, 0) -- move 1 level down to start mining
end

-- === MINING LOGIC ===
local function mineColumn()
  for i = 1, 3 do
    digIfWorth()
    moveForward()
    digDownIfWorth()
    moveDown()
  end
  for i = 1, 3 do moveUp() end
end

local function quarryMine()
  log("Mining started...")
  local sx, sy, sz, sd = pos.x, pos.y, pos.z, dir
  local zig = true

  for z = 1, length do
    for x = 1, width do
      mineColumn()
      if isFull() or turtle.getFuelLevel() < 300 then
        local px, py, pz, pd = pos.x, pos.y, pos.z, dir
        goTo(0, startY, 0, home.dir)
        dumpAll()
        refuelIfNeeded()
        goTo(px, py, pz, pd)
      end
      if x < width then moveForward() end
    end
    if z < length then
      if zig then
        turnRight()
        moveForward()
        turnRight()
      else
        turnLeft()
        moveForward()
        turnLeft()
      end
      zig = not zig
    end
  end

  goTo(0, startY, 0, home.dir)
  dumpAll()
  log("Quarry complete.")
end

-- === EXECUTION ===
prompt()
refuelIfNeeded()
home.dir = dir
drawFilledCobbleFloor()
quarryMine()
