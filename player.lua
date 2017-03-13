Object = require "classic"
Player = Object:extend()

function Player:new()
  self.image = love.graphics.newImage("assets/soldier.png")
  self.x = 25
  self.y = 25
  self.direction = {}
  self.direction.x = 1
  self.direction.y = 0
  self.keysDown = {} -- North('n') South('s') East('e') West('w')
  self.speed = 4
end

function Player:update(dt)
  self:updateDirectionVector()
  if table.getn(self.keysDown) > 0 then
    self.x = self.x + (self.direction.x * self.speed)
    self.y = self.y + (self.direction.y * self.speed)
  end
end

function Player:draw()
  love.graphics.draw(self.image, self.x, self.y)
end

function Player:updateDirectionVector()
  local n = table.getn(self.keysDown)
  if n == 1 then
    local kd = self.keysDown[1]
    self.direction.x = math.cos(kd * (math.pi / 2))
    self.direction.y = math.sin(kd * (math.pi / 2))
  elseif n > 1 then
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

function Player:keyDown(dir)
  for i, v in pairs(self.keysDown) do
    if v == dir then
      return
    end
  end
  table.insert(self.keysDown, dir)
end

function Player:keyUp(dir)
  for i, v in pairs(self.keysDown) do
    if v == dir then
      table.remove(self.keysDown, i)
    end
  end
end
