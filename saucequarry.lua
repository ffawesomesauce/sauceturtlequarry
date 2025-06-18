-- quarry.lua
-- CC:Tweaked Mining Turtle Quarry Script (with outline and 3-block pattern)

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
local startFacing = 0 -- 0=N, 1=E, 2=S, 3=W
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

local function face(targetDir)
  while dir ~= targetDir do
    turnRight()
  end
end

local function moveForward()
  while not turtle.forward() do
    turtle.dig()
    sleep(0.2)
  end
  if dir == 0 then pos.z = pos.z - 1
  elseif dir == 1 then pos.x = pos.x + 1
  elseif dir == 2 then pos.z = pos.z + 1
  elseif dir == 3 then pos.x = pos.x - 1 end
end

local function moveUp()
  while not turtle.up() do
    turtle.digUp()
    sleep(0.2)
  end
  pos.y = pos.y + 1
end

local function moveDown()
  while not turtle.down() do
    turtle.digDown()
    sleep(0.2)
  end
  pos.y = pos.y - 1
end

local function goTo(x, y, z, faceDir)
  while pos.y < y do moveUp() end
  while pos.y > y do moveDown() end

  local dx = x - pos.x
  if dx ~= 0 then
    face((dx > 0) and 1 or 3)
    for i = 1, math.abs(dx) do moveForward() end
  end

  local dz = z - pos.z
  if dz ~= 0 then
    face((dz > 0) and 2 or 0)
    for i = 1, math.abs(dz) do moveForward() end
  end

  face(faceDir)
end

local function refuelIfNeeded()
  if turtle.getFuelLevel() >= 300 then return end
  log("Refueling...")
  for i = 1, 16 do
    turtle.select(i)
    if turtle.getFuelLevel() >= 2000 then break end
    turtle.suck("left")
    while turtle.refuel(1) do
      if turtle.getFuelLevel() >= 2000 then break end
    end
  end
end

local function dumpInventory()
  log("Dumping inventory...")
  for i = 1, 16 do
    turtle.select(i)
    turtle.drop("back")
  end
end

local function isJunk(name)
  return junkBlocks[name] or false
end

local function digSafe()
  local success, data = turtle.inspect()
  if not success or not isJunk(data.name) then
    turtle.dig()
  end
end

local function digDownSafe()
  local success, data = turtle.inspectDown()
  if not success or not isJunk(data.name) then
    turtle.digDown()
  end
end

local function isInventoryFull()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then return false end
  end
  return true
end

-- === MAIN TASKS ===

local function prompt()
  io.write("Enter quarry width: ") width = tonumber(read())
  io.write("Enter quarry length: ") length = tonumber(read())
  io.write("Enter current Y level: ") startY = tonumber(read())
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

local function drawCobbleOutline()
  log("Drawing cobble outline...")
  moveForward() -- step 1 forward before outlining
  moveDown()
  local sx, sz = pos.x, pos.z
  for side = 1, 4 do
    local steps = (side % 2 == 1) and (width - 1) or (length - 1)
    for i = 1, steps do
      placeCobble()
      moveForward()
    end
    turnRight()
  end
  goTo(sx, startY - 1, sz, 0) -- go just under the first cobble tile
end

local function mineColumn()
  for i = 1, 3 do
    digSafe()
    moveForward()
    digDownSafe()
    moveDown()
  end
  for i = 1, 3 do moveUp() end
end

local function quarryLoop()
  log("Mining started...")
  local home = { x = pos.x, y = pos.y, z = pos.z, d = dir }
  local zig = true

  for z = 1, length do
    for x = 1, width do
      mineColumn()
      if turtle.getFuelLevel() < 300 or isInventoryFull() then
        local resume = { x = pos.x, y = pos.y, z = pos.z, d = dir }
        goTo(0, startY, 0, startFacing)
        dumpInventory()
        refuelIfNeeded()
        goTo(resume.x, resume.y, resume.z, resume.d)
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

  goTo(0, startY, 0, startFacing)
  dumpInventory()
  log("Quarry complete.")
end

-- === RUN ===
prompt()
refuelIfNeeded()
drawCobbleOutline()
quarryLoop()
