require "buffer"
require "split"
require "tick"
require "command"
Object = require "classic"
Player = Object:extend()

--- Creates a new Player object
function Player:new(mid, address)
  if mid == "hitman" then
    self.x = 100
    self.y = 100
  elseif mid == "soldier" then
    self.x = 412
    self.y = 100
  elseif mid == "robot" then
    self.x = 100
    self.y = 412
  elseif mid == "survivor" then
    self.x = 412
    self.y = 412
  end
  
  self.angle = 0
  self.mouse = {}
  self.mouse.x = 0
  self.mouse.y = 0
  self.direction = {}
  self.direction.x = 1
  self.direction.y = 0
  self.keysDown = {} -- North('n') South('s') East('e') West('w')
  self.speed = 200
  self.buffer = Buffer()
  self.bufferWidth = 10 -- 5 ticks
  self.ticks = {}
  self.neededTick = self.bufferWidth + 1
  self.currentTick = Tick(self.bufferWidth + 1)
  self.remote = false
  self.connectstatus = true
  if address then
    self.address = address
    self.remote = true
    self.connectstatus = false
  end
  self.mid = mid
  self.image = love.graphics.newImage("assets/" .. self.mid .. ".png")
  
  for i = 1, self.bufferWidth, 1 do
    self.buffer:pushright(Tick(i))
  end
end

--- Updates the player's position/physics.
-- This is called every love.update(dt)
-- @param dt delta time since last called
function Player:update(dt, host)
  -- execute command in buffer 
  self:executeTick(self.buffer:popleft())
  
  -- add commands to buffer (tick + buffer)
  if not self.remote then
    if host then
      host:broadcast(self.currentTick:serialize())
    end
    self.buffer:pushright(self.currentTick)
    self.currentTick = Tick(self.currentTick:getNumber())
  else 
    self:addTicksRemote()
  end
  
  self:updateAngle()
  self:updateDirectionVector()
  if table.getn(self.keysDown) > 0 then
    self.x = self.x + (self.direction.x * self.speed * dt)
    self.y = self.y + (self.direction.y * self.speed * dt)
  end
  print(self.address, self.buffer:getCount())
  self.currentTick:incTickNum()
end

--- Draws the player's image.
-- This is called every love.draw()
function Player:draw()
  love.graphics.draw(self.image, self.x, self.y, self.angle, 1, 1,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
end

--- Updates the direction vector based on direction keys pressed.
-- There are 8 directions total. Every pi/4 spot on the unit circle.
function Player:updateDirectionVector()
  local n = table.getn(self.keysDown)
  if n == 1 then -- If one key is pressed (n, s, e, w)
    local kd = self.keysDown[1]
    self.direction.x = math.cos(kd * (math.pi / 2))
    self.direction.y = math.sin(kd * (math.pi / 2))
  elseif n > 1 then -- (ne, nw, se, sw)
    local kd1 = math.min(self.keysDown[1], self.keysDown[2])
    local kd2 = math.max(self.keysDown[1], self.keysDown[2])
    if not (kd2 - kd1 == 2) then
      if (kd1 == 0) and (kd2 == 3) then
        self.direction.x = math.cos((7/2) * (math.pi / 2))
        self.direction.y = math.sin((7/2) * (math.pi / 2))
      else
        self.direction.x = math.cos((kd1 + (1/2)) * (math.pi / 2))
        self.direction.y = math.sin((kd1 + (1/2)) * (math.pi / 2))
      end
    end
  end
end

--- Executes the tick yo
function Player:executeTick(tick)
  local cmds = tick:getCommands()
  for i, cmd in pairs(cmds) do
    if cmd:getName() == "m" then
      self.mouse.x = cmd:getData()[1]
      self.mouse.y = cmd:getData()[2]
    elseif cmd:getName() == "kd" then
      for i, v in pairs(cmd:getData()) do
        self:keyDown(v)
      end
    elseif cmd:getName() == "ku" then
      for i, v in pairs(cmd:getData()) do
        self:keyUp(v)
      end
    end
  end
end

function Player:addTicks()
  for i, v in pairs(self.ticks) do
    if tonumber(i) == tonumber(self.neededTick) then
      self.buffer:pushright(v)
      self.ticks[i] = nil
      self.neededTick = self.neededTick + 1
      return true
    end
  end
  return false
end

function Player:addTicksRemote()
  while self:addTicks() do
  end
end

function Player:isConnected()
  return self.connectstatus
end

function Player:connected()
  self.connectstatus = true
end

function Player:disconnected()
  self.connectstatus = false
end

--- Updates the character's angle according to the mouse cursor.
function Player:updateAngle()
  self.angle = math.atan2((self.mouse.y - self.y), 
    (self.mouse.x - self.x))
end

--- Adds a direction to the keysDown table unless the direction
-- is already in the table.
-- @param dir The direction pressed. n, s, e, or w
function Player:keyDown(dir)
  for i, v in pairs(self.keysDown) do
    if v == dir then
      return
    end
  end
  table.insert(self.keysDown, dir)
end

--- Removes a direction from the keysDown table.
-- It will also remove multiple occurrances of the direction.
-- @param dir The direction pressed. n, s, e, or w
function Player:keyUp(dir)
  for i, v in pairs(self.keysDown) do
    if v == dir then
      table.remove(self.keysDown, i)
    end
  end
end

function Player:queueKeyDown(key)
  local c = self.currentTick:getCommands()["kd"]
  if c then
    c:addData(key)
  else
    cmd = Command("kd")
    cmd:addData(key)
    self.currentTick:addCommand(cmd)
  end
end

function Player:queueKeyUp(key)
  local c = self.currentTick:getCommands()["ku"]
  if c then
    c:addData(key)
  else
    cmd = Command("ku")
    cmd:addData(key)
    self.currentTick:addCommand(cmd)
  end
end

function Player:queueMouse(x, y)
  if self.currentTick:getCommands()["m"] then
    self.currentTick:modCommandData("m", {x, y})
  else
    cmd = Command("m")
    cmd:addData(x)
    cmd:addData(y)
    self.currentTick:addCommand(cmd)
  end
end

function Player:processTickData(data)
  local splitted = Split.split(data)
  local i = 1
  local n = table.getn(splitted)
  while i <= n do
    if splitted[i] == "t" then
      i = i + 1
      tick = Tick(splitted[i])
    elseif splitted[i] == "m" then
      cmd = Command(splitted[i])
      i = i + 1
      cmd:addData(splitted[i])
      i = i + 1
      cmd:addData(splitted[i])
      tick:addCommand(cmd)
    elseif splitted[i] == "kd" then
      cmd = Command(splitted[i])
      i = i + 1
      for c in string.gmatch(splitted[i], ".") do
        cmd:addData(c)
      end
      tick:addCommand(cmd)
    elseif splitted[i] == "ku" then
      cmd = Command(splitted[i])
      i = i + 1
      for c in string.gmatch(splitted[i], ".") do
        cmd:addData(c)
      end
      tick:addCommand(cmd)
    end
    i = i + 1
  end
  self.ticks[tick:getNumber()] = tick
end

function Player:tickReady(tnum)
  local t = self.buffer:peekleft()
  if t and (tonumber(t:getNumber()) == tonumber(tnum)) then
    return true
  end
  return false
end

--- Returns self.x
function Player:getX()
  return self.x
end

--- Returns self.y
function Player:getY()
  return self.y
end

function Player:isLocal()
  return not self.remote
end

function Player:isRemote()
  return self.remote
end

function Player:getAddress()
  return self.address
end
