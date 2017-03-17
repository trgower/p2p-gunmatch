require "thing"
Movable = Thing:extend()

function Movable:new(world, x, y, xSOff, ySOff, width, height, image, rotation, speed, dx, dy, startMoving)
  
  Movable.super.new(self, world, x, y, xSOff, ySOff, width, height, image, rotation)
  self.speed = speed
  self.direction = {}
  self.direction.x = dx
  self.direction.y = dy
  self.moving = false
  
  self.body:setType("dynamic")
  
end

function Movable:setMoving(m)
  if m then
    self.body:setLinearVelocity(self.direction.x * self.speed,
      self.direction.y * self.speed)
  end
  if (not m) and self.moving then
    self.body:setLinearVelocity(0, 0)
  end
  self.moving = m
end

function Movable:isMoving()
  return self.moving
end

function Movable:getDirection()
  return self.direction
end

function Movable:getDirectionX()
  return self.direction.x
end

function Movable:getDirectionY()
  return self.direction.y
end

function Movable:getSpeed()
  return self.speed
end
