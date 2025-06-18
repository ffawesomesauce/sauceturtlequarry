-- saucequarry.lua (safe fuel handling version)

-- === CONFIG ===
local markerSlot = 1
local skipBlocks = {
  ["minecraft:stone"] = true,
  ["minecraft:cobbled_deepslate"] = true,
  ["minecraft:dirt"] = true,
  ["minecraft:andesite"] = true,
  ["minecraft:granite"] = true,
  ["minecraft:diorite"] = true,
  ["minecraft:netherrack"] = true,
  ["minecraft:soul_sand"] = true,
  ["minecraft:soul_soil"] = true,
  ["minecraft:tuff"] = true
}

-- === UTILS ===
local function estimatedFuel(width, length)
  local area = width * length
  local heightGuess = 64
  return math.ceil(area * heightGuess * 2.2)
end

local function dumpInventoryToBack()
  turtle.turnRight()
  turtle.turnRight()
  for i = 1, 16 do
    if i ~= markerSlot then
      turtle.select(i)
      turtle.drop()
    end
  end
  turtle.turnRight()
  turtle.turnRight()
end

local function pullFuelFromLeft()
  turtle.turnLeft()
  for i = 1, 16 do
    if turtle.getItemCount(i) == 0 then
      turtle.select(i)
      turtle.suck(64)
    end
  end
  turtle.turnRight()
end

local function refuelSafely(requiredFuel)
  local currentFuel = turtle.getFuelLevel()
  if currentFuel >= requiredFuel then return true end

  print("Clearing inventory to make room for fuel...")
  dumpInventoryToBack()

  print("Pulling fuel from left chest...")
  pullFuelFromLeft()

  print("Refueling one item at a time...")
  for i = 1, 16 do
    turtle.select(i)
    while turtle.getItemCount(i) > 0 and turtle.getFuelLevel() < requiredFuel do
      turtle.refuel(1)
    end
    if turtle.getFuelLevel() >= requiredFuel then break end
  end

  if turtle.getFuelLevel() < requiredFuel then
    print("Not enough fuel! Needed: " .. requiredFuel .. ", Have: " .. turtle.getFuelLevel())
    return false
  end

  -- Return extra fuel
  print("Returning leftover fuel to fuel chest...")
  turtle.turnLeft()
  for i = 1, 16 do
    if i ~= markerSlot then
      turtle.select(i)
      turtle.drop()
    end
  end
  turtle.turnRight()
  return true
end

local function pauseForSetup(fuelNeed)
  print("=== Quarry Setup Instructions ===")
  print("- Place cobblestone in slot " .. markerSlot)
  print("- Place a fuel chest to the LEFT of the turtle")
  print("- Place an output chest BEHIND the turtle")
  print("- Quarry will start 1 block in front")
  print("")
  print("Estimated fuel needed: " .. fuelNeed)
  print("Approx:")
  print(" - " .. math.ceil(fuelNeed / 80) .. " coal/charcoal")
  print(" - " .. math.ceil(fuelNeed / 120) .. " blaze rods")
  print(" - " .. math.ceil(fuelNeed / 1000) .. " lava buckets")
  print("")
  print("Press Enter to continue once setup is complete.")
  io.read()
end

local function inspectBlock(dir)
  local success, data
  if dir == "forward" then
    success, data = turtle.inspect()
  elseif dir == "down" then
    success, data = turtle.inspectDown()
  elseif dir == "up" then
    success, data = turtle.inspectUp()
  end
  return success and data.name or nil
end

local function shouldDig(name)
  return not skipBlocks[name or ""]
end

local function digSmart(dir)
  local block = inspectBlock(dir)
  if shouldDig(block) then
    if dir == "forward" then
      turtle.dig()
    elseif dir == "down" then
      turtle.digDown()
    elseif dir == "up" then
      turtle.digUp()
    end
  end
end

local function placeMarker()
  turtle.select(markerSlot)
  turtle.placeDown()
end

local function placeCornerMarker()
  turtle.select(markerSlot)
  turtle.placeDown()
  turtle.up()
  turtle.placeDown()
  turtle.down()
end

local function markPerimeter(w, l)
  for i = 1, 2 do
    for step = 1, (i == 1 and w or l) do
      if (step == 1 or step == (i == 1 and w or l)) then
        placeCornerMarker()
      else
        placeMarker()
      end
      if step < (i == 1 and w or l) then turtle.forward() end
    end
    turtle.turnRight()
  end
  for step = 1, w - 1 do
    turtle.forward()
  end
  turtle.turnRight()
  for step = 1, l - 1 do
    turtle.forward()
  end
  turtle.turnRight()
end

local function dumpInventory()
  turtle.turnRight()
  turtle.turnRight()
  for i = 1, 16 do
    if i ~= markerSlot then
      turtle.select(i)
      turtle.drop()
    end
  end
  turtle.turnRight()
  turtle.turnRight()
end

local function mineColumn()
  while true do
    digSmart("down")
    if not turtle.down() then break end
  end
  while turtle.up() do end
end

local function mineQuarry(w, l)
  for z = 1, l do
    for x = 1, w do
      digSmart("forward")
      turtle.forward()
      mineColumn()
      if turtle.getItemCount(16) > 0 then
        print("Inventory full. Returning to unload...")
        for back = 1, x - 1 do turtle.back() end
        for back = 1, z - 1 do
          turtle.turnRight()
          turtle.turnRight()
          turtle.forward()
          turtle.turnRight()
          turtle.turnRight()
        end
        dumpInventory()
        return mineQuarry(w, l)
      end
    end
    if z < l then
      if z % 2 == 1 then
        turtle.turnRight()
        digSmart("forward")
        turtle.forward()
        turtle.turnRight()
      else
        turtle.turnLeft()
        digSmart("forward")
        turtle.forward()
        turtle.turnLeft()
      end
    end
  end
end

-- === MAIN ===
print("Enter quarry width:")
local width = tonumber(read())
print("Enter quarry length:")
local length = tonumber(read())
local fuelReq = estimatedFuel(width, length)

pauseForSetup(fuelReq)

if not refuelSafely(fuelReq) then
  print("Add more fuel to the LEFT chest and rerun.")
  return
end

print("Marking quarry border...")
turtle.forward()
markPerimeter(width, length)
turtle.back()

print("Starting quarry...")
mineQuarry(width, length)

print("Quarry complete.")
dumpInventory()
