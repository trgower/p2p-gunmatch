require "player"
PlayerController = Player:extend()

function PlayerController:new(world, name, spot)
  PlayerController.super.new(self, world, name, spot)
  self.remote = false
  self.connectstatus = true
end

function PlayerController:update(dt, host)
  PlayerController.super.update(self, dt)
  
  if host then
    host:broadcast(self.currentTick:serialize())
  end
  self.buffer:pushright(self.currentTick)
  self.currentTick = Tick(self.currentTick:getNumber())
  
  self.currentTick:incTickNum()  
end

function PlayerController:queueKeyDown(key)
  local c = self.currentTick:getCommands()["kd"]
  if c then
    c:addData(key)
  else
    cmd = Command("kd")
    cmd:addData(key)
    self.currentTick:addCommand(cmd)
  end
end

function PlayerController:queueKeyUp(key)
  local c = self.currentTick:getCommands()["ku"]
  if c then
    c:addData(key)
  else
    cmd = Command("ku")
    cmd:addData(key)
    self.currentTick:addCommand(cmd)
  end
end

function PlayerController:queueAngle(x, y)
  local a = self:getAngleTo(x, y)
  if self.currentTick:getCommands()["a"] then
    self.currentTick:modCommandData("a", {a})
  else
    cmd = Command("a")
    cmd:addData(a)
    self.currentTick:addCommand(cmd)
  end
end

function PlayerController:queueShoot()
  local c = self.currentTick:getCommands()["s"]
  if not c then
    cmd = Command("s")
    self.currentTick:addCommand(cmd)
  end
end

function PlayerController:setBuffer(b)
  PlayerController.super.setBuffer(self, b)
  self.currentTick = Tick(self.bufferWidth + 1)
end
