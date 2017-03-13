Object = require "classic"
Command = Object:extend()

function Command:new(cmd)
  self.cmd = cmd
  self.data = {}
end

function Command:addData(data)
  table.insert(self.data, data)
end

function Command:getData()
  return self.data
end

function Command:getName()
  return self.cmd
end

function Command:setData(data)
  self.data = data
end
