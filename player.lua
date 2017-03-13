require "buffer"
require "split"
require "tick"
require "command"
Object = require "classic"
Player = Object:extend()

--- Creates a new Player object
function Player:new(cid)
  self.image = love.graphics.newImage("assets/soldier.png")
  self.x = 0
  self.y = 0
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
  self.bufferWidth = 5 -- 5 ticks
  self.ticks = {}
  self.currentTick = Tick(self.bufferWidth + 1)
  self.bufferCount = 0
  self.remote = false
  self.connectid = 0
  if cid then
    self.connectid = cid
  end
  
  for i = 1, self.bufferWidth, 1 do
    self.buffer:pushright(Tick(i))
    self.bufferCount = self.bufferCount + 1
  end
end

--- Updates the player's position/physics.
-- This is called every love.update(dt)
-- @param dt delta time since last called
function Player:update(dt)
  -- execute command in buffer 
  cTick = self.buffer:popleft()
  --print(cTick:getNumber())
  self:executeTick(cTick)
  
  self:updateAngle()
  self:updateDirectionVector()
  if table.getn(self.keysDown) > 0 then
    self.x = self.x + (self.direction.x * self.speed * dt)
    self.y = self.y + (self.direction.y * self.speed * dt)
  end
  
  -- add commands to buffer (tick + buffer)
  if not self.remote then
    self.buffer:pushright(self.currentTick)
    self.bufferCount = self.bufferCount + 1
    self.currentTick = Tick(self.currentTick:getNumber())
  else 
    for i, v in pairs(self.ticks) do
      if i == (self.bufferCount + 1) then
        self.buffer:pushright(v)
        self.bufferCount = self.bufferCount + 1
        self.ticks[i] = nil 
      end
    end
  end
  -- send commands
  
  self.currentTick:incTickNum()
end

--- Draws the player's image.
-- This is called every love.draw()
function Player:draw()
  love.graphics.draw(self.image, self.x, self.y, self.angle, 1, 1,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
  love.graphics.points(self.x, self.y)
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
    elseif splitted[i] == "kd" then
      cmd = Command(splitted[i])
      i = i + 1
      for c in string.gmatch(splitted[i], ".") do
        cmd:addData(c)
      end
    elseif splitted[i] == "ku" then
      cmd = Command(splitted[i])
      i = i + 1
      for c in string.gmatch(splitted[i], ".") do
        cmd:addData(c)
      end
    end
    i = i + 1
  end
  self.ticks[tick:getNumber()] = tick
end

function Player:tickReady(tnum)
  local t = self.buffer:peekleft()
  if t and (t:getNumber() == tnum) then
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
