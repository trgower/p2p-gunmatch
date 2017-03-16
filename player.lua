require "movable"
require "buffer"
require "split"
require "tick"
require "command"
require "bullet"
Player = Movable:extend()

local spots = {{x=100, y=100}, {x=412, y=100}, {x=100, y=412}, {x=412, y=412}}
local models = {"Hitman", "Robot", "Soldier", "Survivor"}

--- Creates a new Player object
function Player:new(world, name, spot, mid)
  Player.super.new(self, world, 0, 0, -10, 0, 20, 40, 
    love.graphics.newImage("assets/" .. spot .. ".png"), 
    0, 200, 1, 0, false)
    
  spot = tonumber(spot)
  mid = tonumber(mid)
  
  self.body:setX(spots[spot].x)
  self.body:setY(spots[spot].y)
  
  self.bullets = {}
  self.world = world
  
  self.name = name
  self.health = 100
  self.latency = 0
  self.keysDown = {} -- North('n') South('s') East('e') West('w')
  self.buffer = Buffer()
  self.bufferWidth = 10
  self.ticks = {}
  self.remote = true
  self.connectstatus = false
  self.reconciled = false
  if mid then
    self.mid = mid
  else
    self.mid = spot
  end
  self.mnum = 4
  
  self.fixture:setSensor(true)
  self.fixture:setUserData(self)
  
end

--- Updates the player's position/physics.
-- This is called every love.update(dt)
-- @param dt delta time since last called
function Player:update(dt)
  self:updateDirectionVector()
  self:setMoving(table.getn(self.keysDown) > 0)
  
  -- execute command in buffer 
  self:executeTick(self.buffer:popleft())
  
  for i, b in ipairs(self.bullets) do
    if b:destroyed() then
      table.remove(self.bullets, i)
    end
  end
end

--- Draws the player's image.
-- This is called every love.draw()
function Player:draw() 
  Player.super.draw(self)
 
  love.graphics.print(self.health, self.body:getX(), self.body:getY() - 25, 0, 
    1, 1, self.image:getWidth() / 2)
 
  if self.remote then
    love.graphics.print(self.name .. "(" .. self.latency .. ")", self.body:getX(), 
      self.body:getY() + 25, 0, 1, 1, self.image:getWidth() / 2)
  else
    love.graphics.print(self.name, self.body:getX(), self.body:getY() + 25, 0, 
      1, 1, self.image:getWidth() / 2)
  end
  
  for i, b in ipairs(self.bullets) do
    b:draw()
  end
  
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

--- Executes the tick
-- Loops through all the commands given in the tick and executes them.
-- @param tick The Tick object to execute
function Player:executeTick(tick)
  local cmds = tick:getCommands()
  for i, cmd in pairs(cmds) do
    if cmd:getName() == "a" then
      self:setAngle(cmd:getData()[1])
    elseif cmd:getName() == "kd" then
      for i, v in pairs(cmd:getData()) do
        self:keyDown(v)
      end
    elseif cmd:getName() == "ku" then
      for i, v in pairs(cmd:getData()) do
        self:keyUp(v)
      end
    elseif cmd:getName() == "s" then
      self:shoot(self.world)
    end
  end
end

--- Adds the next tick needed to the buffer.
-- If the buffer has tick #5 on the right, then it will try to find tick #6 to add.
-- Returns true if a proper tick was found, false otherwise.
function Player:pushNextNeededTick()
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

--- Pushes all ticks on the buffer if possible.
-- Loops until it cannot find a tick to add to the buffer.
function Player:pushAllPossibleTicks()
  while self:pushNextNeededTick() do end
end

--- Updates the character's angle according to the mouse cursor.
function Player:getAngleTo(x, y)
  return math.atan2((y - self.body:getY()), (x - self.body:getX()))
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

function Player:shoot(world)
  table.insert(self.bullets, Bullet(world, self.body:getX(), self.body:getY(),
    self.body:getAngle(), self))
end

function Player:damage(amt)
  self.health = self.health - amt
end

function Player:getName()
  return self.name
end

--- Processes tick data sent over the network into a Tick object.
-- It then adds the Tick object to the table self.ticks and awaits to be added by
-- pushNextNeededTick()
-- @param data byte string sent over the network
function Player:processTickData(data)
  local splitted = Split.split(data)
  local i = 1
  local n = table.getn(splitted)
  while i <= n do
    if splitted[i] == "t" then
      i = i + 1
      tick = Tick(splitted[i])
    elseif splitted[i] == "a" then
      cmd = Command(splitted[i])
      i = i + 1
      cmd:addData(tonumber(splitted[i]))
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
    elseif splitted[i] == "s" then
      cmd = Command(splitted[i])
      tick:addCommand(cmd)
    end
    i = i + 1
  end
  self.ticks[tick:getNumber()] = tick
end

--- Checks if the given tick number is ready to execute in the buffer.
-- @param tnum Tick number corresponding to a tick in the buffer.
function Player:tickReady(tnum)
  local t = self.buffer:peekleft()
  if t and (tonumber(t:getNumber()) == tonumber(tnum)) then
    return true
  end
  return false
end

--- Returns true is player was connected, false otherwise.
function Player:isConnected()
  return self.connectstatus
end

function Player:setcid(cid)
  self.cid = cid
end

--- Sets self.connectstatus to true
function Player:connected(cid)
  if not self:isConnected() then  
    self.cid = cid
    self.connectstatus = true
  end
end

--- Sets self.connectstatus to false
function Player:disconnected()
  self.connectstatus = false
end

--- Returns true if the player object is the local player(you)
function Player:isLocal()
  return not self.remote
end

--- Returns true if the player object is a remote peer(them)
function Player:isRemote()
  return self.remote
end

--- Returns the unique connect_id of the peer assigned to this player.
function Player:getConnectId()
  return self.cid
end

--- Sets self.reconciled.
-- This is used to check if the peer has agreed on a connection to use.
-- This helps remove duplicate connections created by NAT Hole punching
function Player:setReconciled(r)
  self.reconciled = r
end

--- Returns self.reconciled
function Player:isReconciled()
  return self.reconciled
end

--- Sets the tick buffer
-- @param b buffer width
function Player:setBuffer(b)
  self.bufferWidth = b
  self.neededTick = self.bufferWidth + 1
  for i = 1, self.bufferWidth, 1 do
    local t = Tick(i)
    self.buffer:pushright(t)
  end
end

--- Switches model to the model on the "left"
-- This decrements mid if it's greater than 1. Sets it to 4 otherwise
function Player:leftModel()
  if self.mid == 1 then
    self.mid = 4
  else
    self.mid = self.mid - 1
  end
  self.image = love.graphics.newImage("assets/" .. self.mid .. ".png")
end

--- Switches model to the model on the "right"
-- This increments mid if it's less than 4. Sets it to 1 otherwise
function Player:rightModel()
  if self.mid == self.mnum then
    self.mid = 1
  else
    self.mid = self.mid + 1
  end
  self.image = love.graphics.newImage("assets/" .. self.mid .. ".png")
end

--- Return the player's model ID
function Player:getModel()
  return self.mid
end

--- Sets the player's model ID
-- @param m new model id
function Player:setModel(m)
  self.mid = m
  self.image = love.graphics.newImage("assets/" .. self.mid .. ".png")
end

function Player:getModelName()
  return models[self.mid]
end

--- Sets the players latency
-- @param l new latency
function Player:setLatency(l)
  self.latency = l
end
