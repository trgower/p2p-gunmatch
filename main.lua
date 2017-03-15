require "enet"
require "playercontroller"
local suit = require "suit"

local address, port = "107.170.208.8", 34567
local host = enet.host_create()
local cstatus = "connecting..."
local status = ""
local statusUp = false
local statusTimeEnd = 6 -- 6 seconds
local statusTime = 0
local server = host:connect(address..":"..port) -- Queue connect to the server

local leftBtnText = "Host"
local rightBtnText = "Join"
local hosting = false
local joined = false
local ready = false
local running = false
local players = {}
local player = nil
local tick = 1

local reconSent = false

local input = {text = ""}

function statusMessage(msg)
  statusTime = 0
  status = msg
  statusUp = true
end

--- Connect to all players if you are not currently connected
function connectToAll()
  for i, v in pairs(players) do
    if not v:isConnected() then
      host:connect(v:getAddress())
    end
  end
end

--- Returns true if there are other players in the game and they are connected
-- to you. False otherwise.
function allConnected()
  local entered = false
  for i, v in pairs(players) do
    entered = true
    if not v:isConnected() then
      return false
    end
  end
  return entered
end

--- Returns true if all players connect ids have been reconciled, false otherwise
function allReconciled()
  local entered = false
  for i, v in pairs(players) do
    entered = true
    if not v:isReconciled() then
      return false
    end
  end
  return entered
end

--- Pushes as many ticks as possible onto the tick buffer in each player.
function fillPlayersTickBuffer()
  for i, p in pairs(players) do
    p:pushAllPossibleTicks()
  end
end

--- Returns true if every player is ready to execute the next tick
function allTicksRecieved()
  for i, p in ipairs(players) do
    if not p:tickReady(tick) then
      return false
    end
  end
  return true
end

--- Returns the player object with the corresponding remote address
-- @param addy Remote address as string to search for
function getPlayerWithAddress(addy)
  for i, p in pairs(players) do
    if p:getAddress() == addy then
      return p
    end
  end
  return nil
end

--- Lists the peers connected to host and their connect id and state
function listConnectedPeers()
  local i = 1
  print("Connected peers start")
  while host:get_peer(i) and (i < host:peer_count()) and 
      not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
    print(host:get_peer(i), host:get_peer(i):state(), 
      host:get_peer(i):connect_id(), isPeerAttachedToPlayer(host:get_peer(i)))
    i = i + 1
  end
end

--- Returns true if the peer has been assigned to a player, false otherwise
-- @param peer the peer object to search for
function isPeerAttachedToPlayer(peer)
  for i, p in pairs(players) do
    if peer:connect_id() == p:getConnectId() then
      return true
    end
  end
  return false
end

--- Severs the connection of peers that are not assigned to a player.
-- This is normally called after the peers reconcile their connect ids
function resetUnassignedPeers()
  local i = 1
  while host:get_peer(i) and (i < host:peer_count()) and 
      not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
    if not isPeerAttachedToPlayer(host:get_peer(i)) then
      host:get_peer(i):reset()
    end
    i = i + 1
  end
end

--- Sends information necessary to reconcile connect ids
function sendReconcile()
  if (not running) and allConnected() and (not reconSent) then
    
    local i = 1
    while host:get_peer(i) and (i < host:peer_count()) and 
        not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
      local p = getPlayerWithAddress(tostring(host:get_peer(i)))
      if p then
        host:get_peer(i):send("fix " .. p:getConnectId())
      end
      i = i + 1
    end
    
    reconSent = true
  end
end

--- Processes the event given
-- @param event enet event object from service()
function processEvent(event)
  if event.type == "receive" then
    local splitted = Split.split(event.data)
    if splitted[1] == "hostid" then -- Started a lobby!
      input.text = splitted[2]
      hosting = true
      joined = true
      ready = true
      leftBtnText = "Leave"
      rightBtnText = "Start"
      player = PlayerController(splitted[3])
      statusMessage("Host ID Copied to clipboard!")
      love.system.setClipboardText(splitted[2])
    elseif splitted[1] == "joined" then -- A peer has joined the lobby
      local tpeer = Player(splitted[2], splitted[3])
      table.insert(players, tpeer)
      statusMessage("A peer joined")
    elseif splitted[1] == "joingood" then -- You successfully joined a lobby
      joined = true
      rightBtnText = "Ready"
      leftBtnText = "Leave"
      player = PlayerController(splitted[2])
      statusMessage("Joined the lobby")
    elseif splitted[1] == "readygood" then -- You are ready!
      ready = true
      rightBtnText = "Unready"
      statusMessage("Ready!")
    elseif splitted[1] == "unreadygood" then -- You are not ready!
      ready = false
      rightBtnText = "Ready"
      statusMessage("Not ready")
    elseif splitted[1] == "peerinfo" then -- Peer info received after joining
      local tpeer = Player(splitted[2], splitted[3])
      table.insert(players, tpeer)
    elseif splitted[1] == "left" then -- A player has left the lobby/game
      for i, v in pairs(players) do
        if v:getAddress() == splitted[2] then
          players[i] = nil
        end
      end
      statusMessage("A peer has left")
    elseif splitted[1] == "hostleft" then -- The host has left the lobby!
      hosting = false
      joined = false
      ready = false
      leftBtnText = "Host"
      rightBtnText = "Join"
      players = {}
      player = nil
      running = false
      tick = 1
      statusMessage("The host left! Oh NO!")
    elseif splitted[1] == "start" then -- Start the game!
      connectToAll()
    elseif splitted[1] == "fix" then -- Connect ID sent from peer
      local p = getPlayerWithAddress(tostring(event.peer))
      if p then
        if not (p:getConnectId() == tonumber(splitted[2])) then
          -- Chooses the minimum connect id if they don't agree
          if tonumber(splitted[2]) < p:getConnectId() then
            p:setcid(tonumber(splitted[2]))
          end
        end
        p:setReconciled(true)
      end
    else -- Game tick data
      for i, p in pairs(players) do
        if p:getConnectId() == event.peer:connect_id() then
          p:processTickData(event.data)
        end
      end
    end
  elseif event.type == "connect" then
    if event.peer == server then
      cstatus = "connection success!"
    end
    for i, v in pairs(players) do
      if v:getAddress() == tostring(event.peer) then
        players[i]:connected(event.peer:connect_id())
      end
    end
  elseif event.type == "disconnect" then
    if event.peer == server then
      cstatus = "connection failed!"
    end
    for i, v in pairs(players) do
      if v:getAddress() == tostring(event.peer) then
        --players[i]:disconnected()
        players[i] = nil
      end
    end
  end
end

--- Processes events until buffer is empty
-- @param event starting event
function processAllRecievedPackets(event)
  while event do
    processEvent(event)
    event = host:service()
  end
end

function mainMenuUI(dt)
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
        statusMessage("Left the lobby")
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
    
    if statusUp then
      statusTime = statusTime + dt
      if statusTime >= statusTimeEnd then
        statusUp = false
        statusTime = 0
        status = ""
      end
    end
      
    
    suit.layout:reset(156, 375, 4, 4)
    suit.Label(status, suit.layout:row(200, 30))
    
    -- This re-sets the layout in another spot with the same padding. 
    -- This allows us to set other elements regardless of the previous
    -- element placed. It effectively create another layout.
    suit.layout:reset(0, 490, 4, 4)
    suit.Label(cstatus, {align="left"}, suit.layout:row(200, 30))
  end
end

function love.load()
  -- Allows the user to hold down a key to simulate repeated key presses
  love.keyboard.setKeyRepeat(false)
end

function love.update(dt)
  -- Make UI states and stuff
  mainMenuUI(dt);
  
  processAllRecievedPackets(host:service())
  fillPlayersTickBuffer()
  
  -- Start game if everyone is accounted for
  if (not running) and allReconciled() then
    running = true
    resetUnassignedPeers()
  end
  
  sendReconcile()

  -- If we're all connected, and all ticks are ready to be executed and the game
  -- has started...update physics. If not, freeze physics until we are.
  if allConnected() and allTicksRecieved() and running then
    player:queueMouse(love.mouse.getPosition())
    player:update(dt, host)
    for i, p in ipairs(players) do
      p:update(dt)
    end
    
    tick = tick + 1
  end
end -- update(dt)

function love.draw()
  suit.draw()
  for i, p in pairs(players) do
    p:draw()
  end
  if player then
    player:draw()
  end
end

function love.textinput(t)
  suit.textinput(t)
end

function love.keypressed(key)
  suit.keypressed(key)
  
  if key == "v" then
    if love.keyboard.isDown("lctrl") then
      input.text = input.text .. love.system.getClipboardText()
    end
  elseif key == "c" then
    if love.keyboard.isDown("lctrl") then
      love.system.setClipboardText(input.text)
      statusMessage("Copied text in input box")
    end
  elseif key == "x" then
    if love.keyboard.isDown("lctrl") then
      love.system.setClipboardText(input.text)
      input.text = ""
      statusMessage("Cut text in input box")
    end
  end
  
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

