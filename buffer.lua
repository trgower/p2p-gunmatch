Object = require "classic"
Buffer = Object:extend()

function Buffer:new()
  self.buf = {}
  self.first = 0
  self.last = -1
end

function Buffer:pushleft(value)
  local first = self.first - 1
  self.first = first
  self.buf[first] = value
end

function Buffer:pushright(value)
  local last = self.last + 1
  self.last = last
  self.buf[last] = value
end

function Buffer:peekright()
  return self.buf[self.last]
end

function Buffer:peekleft()
  return self.buf[self.first]
end

function Buffer:popleft()
  local first = self.first
  if first > self.first then error("buffer is empty!") end
  local value = self.buf[first]
  self.buf[first] = nil
  self.first = first + 1
  return value
end

function Buffer:popright()
  local last = self.last
  if self.first > last then error("buffer is empty!") end
  local value = self.buf[last]
  self.buf[last] = nil
  self.last = last - 1
  return value
end

function Buffer:getCount()
  local count = 0
  for i, v in pairs(self.buf) do
    count = count + 1
  end
  return count
end
