Object = require "classic"
Bullet = Object:extend()

local colX, colY

function Bullet:new(world, shooter)
  self.world = world
  self.angle = shooter:getAngle()
  self.x = (shooter:getX() - 
    (10 * math.sin(self.angle))) + (30 * math.cos(self.angle))
  self.y = (shooter:getY() + 
    (10 * math.cos(self.angle))) + (30 * math.sin(self.angle))
  
  self.image = love.graphics.newImage("assets/bullet.png")
  
  self.originX = self.x
  self.originY = self.y
  self.speed = 9001
  self.distance = 1000
  self.destroy = false
end

function Bullet:fire()
  self.endX = self.x + (self.distance * math.cos(self.angle))
  self.endY = self.y + (self.distance * math.sin(self.angle))
  
  self.world:rayCast(self.x, self.y, self.endX, self.endY, self.hit)
end

function Bullet.hit(fixture, x, y, xn, yn, fraction)
  fixture:getUserData():damage(1)
  colX = x
  colY = y
  return 1
end

function Bullet:update(dt)
  self.x = self.x + (math.cos(self.angle) * self.speed * dt)
  self.y = self.y + (math.sin(self.angle) * self.speed * dt)
  
  if colX and (not self.distanceToCollision) then
    self.distanceToCollision = self:distanceTo(colX, colY)
  end
  if self.distanceToCollision and
    ((self:distanceTo(self.originX, self.originY) > self.distanceToCollision) or
    (self:distanceTo(self.originX, self.originY) > self.distance)) then
    self.destroy = true
  end
  
end

function Bullet:draw()
  love.graphics.draw(self.image, self.x, self.y, self.angle, 5, 0.1,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
end

function Bullet:distanceTo(x, y) 
  return math.sqrt((x - self.x) ^ 2 + (y - self.y) ^ 2) 
end

function Bullet:isDestroyed()
  return self.destroy
end
