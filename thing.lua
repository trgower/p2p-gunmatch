Object = require "classic"
Thing = Object:extend()

function Thing:new(world, x, y, xSOff, ySOff, width, height, image, rotation)
  self.width = width
  self.height = height
  self.image = image
  
  self.body = love.physics.newBody(world, x, y)
  self.body:setAngle(rotation)
  self.shape = love.physics.newRectangleShape(x + xSOff, y + ySOff, width, height, rotation)
  self.fixture = love.physics.newFixture(self.body, self.shape)
end

function Thing:draw()
  love.graphics.draw(self.image, self.body:getX(), self.body:getY(), 
    self.body:getAngle(), 1, 1,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
end

function Thing:setPosition(x, y)
  self.body:setX(x)
  self.body:setY(y)
end

function Thing:setX(x)
  self.body:setX(x)
end

function Thing:setY(y)
  self.body:setY(y)
end

function Thing:getX()
  return self.body:getX()
end

function Thing:getY()
  return self.body:getY()
end

function Thing:getWidth()
  return self.width
end

function Thing:getHeight()
  return self.height
end

function Thing:getImage()
  return self.image
end

function Thing:setImage(image)
  self.image = image
end

function Thing:setAngle(rotation)
  self.body:setAngle(rotation)
end

function Thing:getRotation() 
  return self.body:getAngle()
end

function Thing:destroy()
  self.fixture:destroy()
end

function Thing:destroyed()
  return self.fixture:isDestroyed()
end
