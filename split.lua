Object = require "classic"
Split = Object:extend()

function Split.split(string)
  local splitted = {}
  for i in string.gmatch(string, "%S+") do
    table.insert(splitted, i)
  end
  return splitted
end
