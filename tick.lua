Object = require "classic"
Tick = Object:extend()

function Tick:new(number)
  self.number = number
  self.commands = {}
end

function Tick:getNumber()
  return self.number
end

function Tick:addCommand(command)
  --table.insert(commands, command)
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
