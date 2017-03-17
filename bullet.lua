require "movable"
Bullet = Movable:extend()

function Bullet:new(world, x, y, angle, shooter)
  Bullet.super.new(self, world, 0, 0, 0, 0, 10, 7, 
    love.graphics.newImage("assets/bullet.png"), angle, 3000, 
    math.cos(angle), math.sin(angle), true)
  self.body:setX((x - (10 * math.sin(angle))) + (30 * math.cos(angle)))
  self.body:setY((y + (10 * math.cos(angle))) + (30 * math.sin(angle)))
  self.body:setBullet(true)
  self.shooter = shooter
  
  self.fixture:setSensor(true)
  self.fixture:setUserData(self)
  self:setMoving(true)
end

function Bullet:draw()
  love.graphics.draw(self.image, self.body:getX(), self.body:getY(), 
    self.body:getAngle(), 0.5, 0.5,
    self.image:getWidth() / 2, self.image:getHeight() / 2)
    
  --love.graphics.polygon("line", self.body:getWorldPoints(self.shape:getPoints()))
end
