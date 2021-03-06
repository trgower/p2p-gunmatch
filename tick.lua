Object = require "classic"
Tick = Object:extend()

function Tick:new(number)
  self.number = tonumber(number)
  self.commands = {}
end

function Tick:getNumber()
  return self.number
end

function Tick:addCommand(command)
  self.commands[command:getName()] = command
end

function Tick:modCommandData(index, data)
  self.commands[index].setData(data)
end

function Tick:getCommands()
  return self.commands
end

function Tick:incTickNum()
  self.number = self.number + 1
end

function Tick:serialize()
  local ser = "t " .. self.number
  for i, v in pairs(self.commands) do
    if i == "a" then
      ser = ser .. " " .. i .. " " .. v:getData()[1]
    elseif i == "kd" then
      ser = ser .. " " .. i .. " "
      for j, k in pairs(v:getData()) do
        ser = ser .. k
      end
    elseif i == "ku" then
      ser = ser .. " " .. i .. " "
      for j, k in pairs(v:getData()) do
        ser = ser .. k
      end
    elseif i == "s" then
      ser = ser .. " " .. i
    end
  end
  return ser
end
