require "enet"
require "player"
local suit = require "suit"

local address, port = "107.170.208.8", 34567
local host = enet.host_create()
local status = "Status: loading..."
local server = host:connect(address..":"..port) -- Queue connect to the server
local event = host:service(100) -- Send queued packets

local leftBtnText = "Host"
local rightBtnText = "Join"
local hosting = false
local joined = false
local ready = false
local running = false
local players = {}
local player = nil
local tick = 1

local input = {text = ""}

function connectToAll()
  for i, v in pairs(players) do
    if not v:isConnected() then
      host:connect(v:getAddress())
    end
  end
end

function allConnected()
  for i, v in pairs(players) do
    if not v:isConnected() then
      return false
    end
  end
  return true
end

function love.load()
  -- Allows the user to hold down a key to simulate repeated key presses
  love.keyboard.setKeyRepeat(false)
  
  if event and (event.type == "connect") then
    status = "Status: connected to server"
  else
    status = "Status: not connected"
  end
end

function love.update(dt)
  event = host:service()
  if event and (event.type == "receive") then
    local splitted = Split.split(event.data)
    if splitted[1] == "hostid" then
      input.text = splitted[2]
      hosting = true
      joined = true
      ready = true
      leftBtnText = "Leave"
      rightBtnText = "Start"
      player = Player(splitted[3])
      table.insert(players, player)
    elseif splitted[1] == "joined" then
      local p = Player(splitted[2], splitted[3])
      table.insert(players, p)
    elseif splitted[1] == "joingood" then
      joined = true
      rightBtnText = "Ready"
      leftBtnText = "Leave"
      player = Player(splitted[2])
      table.insert(players, player)
    elseif splitted[1] == "readygood" then
      ready = true
      rightBtnText = "Unready"
    elseif splitted[1] == "unreadygood" then
      ready = false
      rightBtnText = "Ready"
    elseif splitted[1] == "peerinfo" then
      local tpeer = Player(splitted[2], splitted[3])
      table.insert(players, tpeer)
    elseif splitted[1] == "left" then
      for i, v in pairs(players) do
        if v:getAddress() == splitted[2] then
          players[i] = nil
        end
      end
    elseif splitted[1] == "hostleft" then
      hosting = false
      joined = false
      ready = false
      leftBtnText = "Host"
      rightBtnText = "Join"
      players = {}
      player = nil
      running = false
      tick = 1
    elseif splitted[1] == "start" then
      for i, v in pairs(players) do
        if not (v == player) then
          print("connecting to " .. v:getAddress())
          host:connect(v:getAddress())
        end
      end
      running = true
    else
      for i, p in pairs(players) do
        if p:getAddress() == tostring(event.peer) then
          p:processTickData(event.data)
          --print(tostring(event.peer), event.data)
        end
      end
    end
  elseif event and (event.type == "connect") then
    print("connected to " .. tostring(event.peer))
    for i, v in pairs(players) do
      if v:getAddress() == tostring(event.peer) then
        players[i]:connected()
      end
    end
  elseif event and (event.type == "disconnect") then
    for i, v in pairs(players) do
      if v:getAddress() == tostring(event.peer) then
        players[i]:disconnected()
      end
    end
  end
  
  if not running then
    -- This "resets" the layout, which means it literally re-sets the layout
    -- in a different spot with a padding of 4 on left, right, top and bottom.
    suit.layout:reset(156, 300, 4, 4)
    
    -- This simply creates a text field in the layout set above with a
    -- width of 200 and height of 30.
    suit.Input(input, suit.layout:row(200, 30)) -- Host ID Box
    
    -- The left button is set in the layout in a row under the last element
    -- placed (host id textfield). The label and function of the button changes 
    -- based on the user being in a lobby or not.
    if suit.Button(leftBtnText, suit.layout:row(98, 30)).hit then
      if hosting or joined then     -- click Leave
        hosting = false
        joined = false
        ready = false
        leftBtnText = "Host"
        rightBtnText = "Join"
        players = {}
        player = nil
        running = false
        tick = 1
        server:send("leave")
      else                          -- click Host
        server:send("host")
      end
    end
    
    -- The right button is set in the layout in a column to the right of
    -- the last element placed. The label and function also changes, but 
    -- has 4 states instead of 2.
    if suit.Button(rightBtnText, suit.layout:col(98, 30)).hit then
      if not joined then            -- click Join
        if tonumber(input.text) then
          server:send("join " .. input.text)
        else
          print("Host ID must be a number!")
        end
      elseif hosting then           -- click Start
        server:send("start")
      elseif not ready then         -- click Ready
        server:send("ready")
      else                          -- click Unready
        server:send("unready")
      end
    end
    
    -- This re-sets the layout in another spot with the same padding. 
    -- This allows us to set other elements regardless of the previous
    -- element placed. It effectively create another layout.
    suit.layout:reset(156, 375, 4, 4)
    suit.Label(status, suit.layout:row(200, 30))
  end
  
  local commandsReceived = true
  for i, p in ipairs(players) do
    if not p:tickReady(tick) then
      commandsReceived = false
      p:addTicksRemote()
    end
  end
  if allConnected() and commandsReceived and running then
    for i, p in ipairs(players) do
      if p:isLocal() then
        p:queueMouse(love.mouse.getPosition())
        p:update(dt, host)
      else
        p:update(dt)
      end
    end
    
    tick = tick + 1
  end
  
end -- update(dt)

function love.draw()
  suit.draw()
  for i, p in pairs(players) do
    p:draw()
  end
end

function love.textinput(t)
  suit.textinput(t)
end

function love.keypressed(key)
  suit.keypressed(key)
  
  if player and running then
    if (key == "up") or (key == "w") then
      player:queueKeyDown(3)
    elseif (key == "left") or (key == "a") then
      player:queueKeyDown(2)
    elseif (key == "down") or (key == "s") then
      player:queueKeyDown(1)
    elseif (key == "right") or (key == "d") then
      player:queueKeyDown(0)
    end
  end
end

function love.keyreleased(key)
  if player and running then
    if (key == "up") or (key == "w") then
      player:queueKeyUp(3)
    elseif (key == "left") or (key == "a") then
      player:queueKeyUp(2)
    elseif (key == "down") or (key == "s") then
      player:queueKeyUp(1)
    elseif (key == "right") or (key == "d") then
      player:queueKeyUp(0)
    end
  end
end

