require "player"
PlayerController = Player:extend()

function PlayerController:new(mid)
  PlayerController.super.new(self, mid)
  PlayerController.super.remote = false
  PlayerController.super.connectstatus = true
  
  self.currentTick = Tick(self.bufferWidth + 1)
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

function PlayerController:queueMouse(x, y)
  if self.currentTick:getCommands()["m"] then
    self.currentTick:modCommandData("m", {x, y})
  else
    cmd = Command("m")
    cmd:addData(x)
    cmd:addData(y)
    self.currentTick:addCommand(cmd)
  end
end
