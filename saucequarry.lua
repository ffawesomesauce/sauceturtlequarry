-- quarry.lua
-- CC:Tweaked Mining Turtle Quarry Script

-- === CONFIG ===
local JUNK_BLOCKS = {
  minecraft = {
    stone = true,
    cobbled_deepslate = true,
    dirt = true,
    granite = true,
    diorite = true,
    netherrack = true,
    soul_sand = true,
    soul_soil = true,
    tuff = true
  }
}

-- === GLOBALS ===
local width, length, startY, fuelCap = 0, 0, 0, turtle.getFuelLimit()
local startX, startZ, facing = 0, 0, 0 -- relative movement system
local mined = {} -- track mined blocks
local dumpChestDir = "back"
local supplyChestDir = "left"

-- === UTILITIES ===

local function log(msg) print("[Quarry] " .. msg) end

local function refuelIfNeeded()
  if turtle.getFuelLevel() >= 300 then return end
  log("Refueling...")
  turtle.select(1)
  turtle.suck(supplyChestDir)
  for slot = 1, 16 do
    turtle.select(slot)
    while turtle.refuel(1) do
      if turtle.getFuelLevel() >= 2000 or turtle.getFuelLevel() == fuelCap then
        log("Fuel topped up to " .. turtle.getFuelLevel())
        return
      end
    end
  end
end

local function dumpInventory()
  log("Dumping inventory...")
  for slot = 1, 16 do
    turtle.select(slot)
    turtle.drop(dumpChestDir)
  end
end

local function isJunk(name)
  for prefix, list in pairs(JUNK_BLOCKS) do
    if name:find(prefix .. ":") == 1 then
      local suffix = name:sub(#prefix + 2)
      if list[suffix] then return true end
    end
  end
  return false
end

local function checkFull()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then return false end
  end
  return true
end

local function returnHome()
  log("Returning to surface...")
  while startY < select(2, gps.locate()) do turtle.up() end
  -- No persistent position tracking yet; assumes turtle returns to exact start tile
  dumpInventory()
  refuelIfNeeded()
end

local function digIfUseful()
  local success, data = turtle.inspect()
  if not success or not isJunk(data.name) then
    turtle.dig()
  end
end

local function digDownIfUseful()
  local success, data = turtle.inspectDown()
  if not success or not isJunk(data.name) then
    turtle.digDown()
  end
end

local function mineColumn()
  for i = 1, 3 do
    digIfUseful()
    turtle.forward()
    digDownIfUseful()
    turtle.down()
  end
  -- climb back up
  for i = 1, 3 do turtle.up() end
end

-- === POSITIONAL HELPERS (dummy facing) ===

local function face(dir)
  while facing ~= dir do
    turtle.turnRight()
    facing = (facing + 1) % 4
  end
end

local function moveForward(n)
  for i = 1, n do
    while not turtle.forward() do
      digIfUseful()
      sleep(0.5)
    end
  end
end

local function moveUp(n)
  for i = 1, n do
    while not turtle.up() do
      turtle.digUp()
      sleep(0.5)
    end
  end
end

local function moveDown(n)
  for i = 1, n do
    while not turtle.down() do
      turtle.digDown()
      sleep(0.5)
    end
  end
end

-- === SETUP ===

local function setup()
  print("Enter quarry width:")
  width = tonumber(read())
  print("Enter quarry length:")
  length = tonumber(read())
  print("Enter current Y height:")
  startY = tonumber(read())

  facing = 0 -- assume north at start
  startX, startZ = 0, 0
end

-- === OUTLINE ===

local function placeCobble()
  for i = 1, 16 do
    local item = turtle.getItemDetail(i)
    if item and item.name:find("cobblestone") then
      turtle.select(i)
      return turtle.placeDown()
    end
  end
  return false
end

local function drawOutline()
  log("Drawing cobble outline...")
  turtle.forward()
  turtle.down()
  for side = 1, 4 do
    local distance = (side % 2 == 1) and width or length
    for i = 1, distance - 1 do
      placeCobble()
      moveForward(1)
    end
    placeCobble()
    turtle.turnRight()
    facing = (facing + 1) % 4
  end

  -- place 2-high corner pillars
  for i = 1, 4 do
    turtle.select(1)
    turtle.up()
    placeCobble()
    turtle.down()
    turtle.turnLeft()
    facing = (facing - 1) % 4
    moveForward((i % 2 == 1) and (width - 1) or (length - 1))
  end

  -- Return to corner
  turtle.turnLeft()
  turtle.turnLeft()
  moveForward(width - 1)
  turtle.turnRight()
  moveForward(length - 1)
  turtle.turnLeft()
end

-- === MINING LOOP ===

local function quarry()
  log("Starting quarry...")
  local direction = true
  for z = 1, length do
    for x = 1, width do
      mineColumn()
      if checkFull() or turtle.getFuelLevel() < 300 then
        returnHome()
      end
      if x < width then
        turtle.forward()
      end
    end
    if z < length then
      if direction then
        turtle.turnRight()
        turtle.forward()
        turtle.turnRight()
      else
        turtle.turnLeft()
        turtle.forward()
        turtle.turnLeft()
      end
      direction = not direction
    end
  end
end

-- === MAIN ===
setup()
refuelIfNeeded()
drawOutline()
quarry()
returnHome()
log("Quarry complete.")
