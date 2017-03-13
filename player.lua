Object = require "classic"
Player = Object:extend()

--- Creates a new Player object
function Player:new()
  self.image = love.graphics.newImage("assets/soldier.png")
  self.x = 0
  self.y = 0
  self.angle = 0
  self.direction = {}
  self.direction.x = 1
  self.direction.y = 0
  self.keysDown = {} -- North('n') South('s') East('e') West('w')
  self.speed = 200
end

--- Updates the player's position/physics.
-- This is called every love.update(dt)
-- @param dt delta time since last called
function Player:update(dt)
  self:updateAngle()
  self:updateDirectionVector()
  if table.getn(self.keysDown) > 0 then
    self.x = self.x + (self.direction.x * self.speed * dt)
    self.y = self.y + (self.direction.y * self.speed * dt)
  end
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

--- Updates the character's angle according to the mouse cursor.
function Player:updateAngle()
  self.angle = math.atan2((love.mouse.getY() - self.y), 
    (love.mouse.getX() - self.x))
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

--- Returns self.x
function Player:getX()
  return self.x
end

--- Returns self.y
function Player:getY()
  return self.y
end
