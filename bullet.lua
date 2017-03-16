require "movable"
Bullet = Movable:extend()

function Bullet:new(world, x, y, angle, shooter)
  Bullet.super.new(self, world, 0, 0, 0, 0, 8, 5, 
    love.graphics.newImage("assets/bullet.png"), angle, 1000, 
    math.cos(angle), math.sin(angle), true)
  self.body:setX(x + (12 * math.cos(angle)))
  self.body:setY(y + (12 * math.sin(angle)))
  self.body:setBullet(true)
  self.shooter = shooter
  self.fixture:setUserData(self)
end

function Bullet:draw()
  love.graphics.draw(self.image, self.body:getX(), self.body:getY(), 
    self.body:getAngle(), 0.5, 0.5,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
end
