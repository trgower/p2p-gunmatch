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

local lastBandOut = 0
local lastBandIn = 0
local bandMeasureTime = 0
local bandEverySeconds = 1
local bandOut = 0
local bandIn = 0

local pingMeasureTime = 0
local pingEverySeconds = 0.3

local hostIdInput = {text = ""}
local nameInput = {text = "Player"}
local bufferInput = 10

local fixedStep = 0.01666 / 2 -- 120Hz (why not)

function love.load()
  -- Allows the user to hold down a key to simulate repeated key presses
  love.keyboard.setKeyRepeat(false)
  
  world = love.physics.newWorld(0, 0)
  world:setCallbacks(beginContact, endContact, preSolve, postSolve)
  
end

function love.setUpdateTimestep(ts)
  love.updateTimestep = ts
end

function love.run()

  love.setUpdateTimestep(fixedStep)

  math.randomseed( os.time() )
  math.random() math.random()
  
  if love.load then love.load(arg) end
  
  local dt = 0
  local accumulator = 0
  
  -- Main loop
  while true do
  
    -- Process events.
    if love.event then
      love.event.pump()
      for e,a,b,c,d in love.event.poll() do
        if e == "quit" then
          if not love.quit or not love.quit() then
            if love.audio then love.audio.stop() end
            return
          end
        end
        love.handlers[e](a,b,c,d)
      end
    end
        
    -- Update dt for any uses during this timestep of love.timer.getDelta
    if love.timer then 
      love.timer.step()
      dt = love.timer.getDelta()
    end

    local fixedTimestep = love.updateTimestep
    
    if fixedTimestep then       
      -- see http://gafferongames.com/game-physics/fix-your-timestep  
      
      if dt > 0.25 then      
        dt = 0.25 -- note: max frame time to avoid spiral of death
      end     
      
      accumulator = accumulator + dt
      --_logger:debug("love.run - acc=%f fts=%f", accumulator, fixedTimestep) 

      while accumulator >= fixedTimestep do
        if love.update then love.update(fixedTimestep) end
        accumulator = accumulator - fixedTimestep
      end
      
    else
      -- no fixed timestep in place, so just update
      -- will pass 0 if love.timer is disabled
      if love.update then love.update(dt) end 
    end
    
    -- draw
    if love.graphics then
      love.graphics.clear()
      if love.draw then love.draw() end
      if love.timer then love.timer.sleep(0.001) end
      love.graphics.present()
    end
      
  end
  
end

--- Called every dt seconds
-- This is used to update the world's phyiscs and game state.
-- @param dt delta time in seconds since last call
function love.update(dt)

  -- Measure ping between all peers
  pingMeasureTime = pingMeasureTime + dt
  if pingMeasureTime >= pingEverySeconds then
    local i = 1
    while host:get_peer(i) and (i < host:peer_count()) and 
      not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
      local p = players[tostring(host:get_peer(i))]
      if p then
        p:setLatency(host:get_peer(i):round_trip_time())
      end
      i = i + 1
    end
    pingMeasureTime = 0
  end
  
  love.processAllRecievedPackets(host:service(5))
  -- Push all possible ticks to buffer in each player
  for i, p in pairs(players) do
    p:pushAllPossibleTicks()
  end
  
  -- Start game if everyone is accounted for
  if (not running) and love.allReconciled() then
    running = true
    love.resetUnassignedPeers()
  end
  
  -- If not running
  love.sendReconcile()

  -- If we're all connected, and all ticks are ready to be executed and the game
  -- has started...update physics. If not, freeze physics until we are.
  if love.allConnected() and love.allTicksRecieved() and running then
    world:update(dt)
    player:queueAngle(love.mouse.getPosition())
    player:update(dt, host)
    for i, p in pairs(players) do
      p:update(dt)
    end

    tick = tick + 1
  end
  
  -- Measure bandwidth
  bandMeasureTime = bandMeasureTime + dt
  if bandMeasureTime >= bandEverySeconds then
    local currOut = host:total_sent_data()
    local currIn = host:total_received_data()
    bandOut = (currOut - lastBandOut)
    bandIn = (currIn - lastBandIn)
    lastBandOut = currOut
    lastBandIn = currIn
    bandMeasureTime = 0
  end
  
  if statusUp then
    statusTime = statusTime + dt
    if statusTime >= statusTimeEnd then
      statusUp = false
      statusTime = 0
      status = ""
    end
  end
  
end -- update(dt)

--- Called after update(dt)
-- This is used to draw anything on the screen
function love.draw()
  -- Make UI states and stuff
  love.mainMenuUI(dt);
  
  suit.draw()
  for i, p in pairs(players) do
    p:draw()
  end
  if player then
    player:draw()
  end
end

--- Processes the event given
-- @param event enet event object from service()
function love.processEvent(event)
  if event.type == "receive" then
    local splitted = Split.split(event.data)
    if splitted[1] == "hostid" then -- Started a lobby!
      hostIdInput.text = splitted[2]
      hosting = true
      joined = true
      ready = true
      leftBtnText = "Leave"
      rightBtnText = "Start"
      player = PlayerController(world, splitted[4], splitted[3])
      statusMessage("Host ID Copied to clipboard!")
      love.system.setClipboardText(splitted[2])
    elseif splitted[1] == "joined" then -- A peer has joined the lobby
      local tpeer = Player(world, splitted[2], splitted[4])
      players[splitted[3]] = tpeer
      statusMessage("A peer joined")
    elseif splitted[1] == "joingood" then -- You successfully joined a lobby
      joined = true
      rightBtnText = "Ready"
      leftBtnText = "Leave"
      player = PlayerController(world, splitted[3], splitted[2])
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
      local tpeer = Player(world, splitted[5], splitted[3], splitted[4])
      players[splitted[2]] = tpeer
    elseif splitted[1] == "left" then -- A player has left the lobby/game
      players[splitted[2]] = nil
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
      love.setBuffer(tonumber(splitted[2]))
      -- Connect to all players that are not currently connected
      for i, v in pairs(players) do
        if not v:isConnected() then
          host:connect(i)
        end
      end
    elseif splitted[1] == "bdk" then -- Buffer down ok
      bufferInput = bufferInput - 1
    elseif splitted[1] == "buk" then -- Buffer up ok
      bufferInput = bufferInput + 1
    elseif splitted[1] == "ccu" then -- character change update
      local p = players[splitted[2]]
      p:setModel(tonumber(splitted[3]))
    elseif splitted[1] == "fix" then -- Connect ID sent from peer
      local p = players[tostring(event.peer)]
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
      cstatus = "connected"
    else
     players[tostring(event.peer)]:connected(event.peer:connect_id())
    end
  elseif event.type == "disconnect" then
    if event.peer == server then
      cstatus = "disconnected"
    else
      players[tostring(event.peer)] = nil
    end
  end
end

--- Processes events until buffer is empty
-- @param event starting event
function love.processAllRecievedPackets(event)
  while event do
    love.processEvent(event)
    event = host:service()
  end
end

--- Updates the main UI
-- @param dt delta time since last update(dt) call
function love.mainMenuUI()
  if not running then
    if joined then
      -- Skin change buttons
      suit.layout:reset(168, 478, 4, 4)
      
      if suit.Button("<", suit.layout:row(40, 30)).hit then
        player:leftModel()
        server:send("pmu " .. player:getModel())
      end
      suit.Label(player:getModelName(), {align="center"}, suit.layout:col(80, 30))
      if suit.Button(">", suit.layout:col(40, 30)).hit then
        player:rightModel()
        server:send("pmu " .. player:getModel())
      end
    end
    
    if hosting then
      -- Buffer buttons
      suit.layout:reset(410, 478, 4, 4)
      
      if suit.Button("-", suit.layout:col(30, 30)).hit then
        server:send("bd")
      end
      suit.Label(bufferInput, {align="center"}, suit.layout:col(30, 30))
      if suit.Button("+", suit.layout:col(30, 30)).hit then
        server:send("bu")
      end
    end
    
    -- This "resets" the layout, which means it literally re-sets the layout
    -- in a different spot with a padding of 4 on left, right, top and bottom.
    suit.layout:reset(156, 300, 4, 4)
    
    if not joined then
      suit.Label("Name", {align="left"}, suit.layout:row(150, 20))
      suit.Input(nameInput, suit.layout:row(200, 30))
    end
    
    -- This simply creates a text field in the layout set above with a
    -- width of 200 and height of 30.
    if (not joined) or hosting then
      suit.Label("Host ID", {align="left"}, suit.layout:row(150, 20))
      suit.Input(hostIdInput, suit.layout:row(200, 30)) -- Host ID Box
    else
      suit.layout:row(200, 30)
    end
    
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
        if not (nameInput.text == "") then
          server:send("host " .. nameInput.text)
        else
          statusMessage("You must enter a name!")
        end
      end
    end
    
    -- The right button is set in the layout in a column to the right of
    -- the last element placed. The label and function also changes, but 
    -- has 4 states instead of 2.
    if suit.Button(rightBtnText, suit.layout:col(98, 30)).hit then
      if not joined then            -- click Join
        if tonumber(hostIdInput.text) then
          if not (nameInput.text == "") then
            server:send("join " .. hostIdInput.text .. " " .. nameInput.text)
          else
            statusMessage("You must enter a name!")
          end
        end
      elseif hosting then           -- click Start
        server:send("start")
      elseif not ready then         -- click Ready
        server:send("ready")
      else                          -- click Unready
        server:send("unready")
      end
    end
    
    suit.layout:reset(156, 0, 4, 4)
    suit.Label(status, suit.layout:row(200, 30))
    
    -- This re-sets the layout in another spot with the same padding. 
    -- This allows us to set other elements regardless of the previous
    -- element placed. It effectively create another layout.
    suit.layout:reset(0, 490, 4, 4)
    suit.Label(cstatus, {align="left"}, suit.layout:row(150, 30))
  else
    suit.layout:reset(0, 470, 0, 0)
    suit.Label("up: " .. love.round(bandOut / 1024, 1) .. "kB/s", {align="left"}, suit.layout:row(150, 20))
    suit.Label("down: " .. love.round(bandIn / 1024, 1) .. "kB/s", {align="left"}, suit.layout:row(150, 20))
  end
end

function love.textinput(t)
  suit.textinput(t)
end

--- Called when a key is pressed
-- @param key the key code that was pressed
function love.keypressed(key)
  suit.keypressed(key)
  
  -- Knock off copy, cut and paste function
  if key == "v" then
    if love.keyboard.isDown("lctrl") then
      hostIdInput.text = hostIdInput.text .. love.system.getClipboardText()
    end
  elseif key == "c" then
    if love.keyboard.isDown("lctrl") then
      love.system.setClipboardText(hostIdInput.text)
      statusMessage("Copied text in input box")
    end
  elseif key == "x" then
    if love.keyboard.isDown("lctrl") then
      love.system.setClipboardText(hostIdInput.text)
      hostIdInput.text = ""
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

--- Called when a key is released
-- @param key the key code that was released
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

function love.mousepressed(x, y, button, istouch)
  if player and running then
    if button == 1 then
      player:queueShoot()
    end
  end
end

function beginContact(a, b, coll)
  if a:getUserData().shooter and b:getUserData().shooter then
    a:getUserData():destroy()
    b:getUserData():destroy()
  elseif a:getUserData().shooter then -- a is the bullet
    b:getUserData():damage(5)
    a:getUserData():destroy()
  elseif b:getUserData().shooter then -- b is the bullet
    a:getUserData():damage(5)
    b:getUserData():destroy()
  end
end
 
function endContact(a, b, coll)
end
 
function preSolve(a, b, coll)
end
 
function postSolve(a, b, coll, normalimpulse, tangentimpulse)
end

--- Draws a message on the screen for 6 seconds
-- @param msg message to draw
function statusMessage(msg)
  statusTime = 0
  status = msg
  statusUp = true
end

--- Rounds a number to the specified number of decimal places
-- @param num number to round
-- @param numDecimalPlaces number of decimal places
function love.round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math.floor(num * mult + 0.5) / mult
end

--- Sets the buffer for the game for each player
-- This is usually called right before the game starts
-- @param b the buffer width (default=10)
function love.setBuffer(b)
  player:setBuffer(b)
  for i, p in pairs(players) do
    p:setBuffer(b)
  end
end

--- Returns true if there are other players in the game and they are connected
-- to you. False otherwise.
function love.allConnected()
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
function love.allReconciled()
  local entered = false
  for i, v in pairs(players) do
    entered = true
    if not v:isReconciled() then
      return false
    end
  end
  return entered
end

--- Returns true if every player is ready to execute the next tick
function love.allTicksRecieved()
  for i, p in pairs(players) do
    if not p:tickReady(tick) then
      return false
    end
  end
  return true
end

--- Lists the peers connected to host and their connect id and state
function love.listConnectedPeers()
  local i = 1
  print("Connected peers start")
  while host:get_peer(i) and (i < host:peer_count()) and 
      not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
    print(host:get_peer(i), host:get_peer(i):state(), 
      host:get_peer(i):connect_id(), love.isPeerAttachedToPlayer(host:get_peer(i)))
    i = i + 1
  end
end

--- Returns true if the peer has been assigned to a player, false otherwise
-- @param peer the peer object to search for
function love.isPeerAttachedToPlayer(peer)
  for i, p in pairs(players) do
    if peer:connect_id() == p:getConnectId() then
      return true
    end
  end
  return false
end

--- Severs the connection of peers that are not assigned to a player.
-- This is normally called after the peers reconcile their connect ids
function love.resetUnassignedPeers()
  local i = 1
  while host:get_peer(i) and (i < host:peer_count()) and 
      not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
    if not love.isPeerAttachedToPlayer(host:get_peer(i)) then
      host:get_peer(i):reset()
    end
    i = i + 1
  end
end

--- Sends information necessary to reconcile connect ids
function love.sendReconcile()
  if (not running) and love.allConnected() and (not reconSent) then
    
    local i = 1
    while host:get_peer(i) and (i < host:peer_count()) and 
        not (tostring(host:get_peer(i)) == "0.0.0.0:0") do
      local p = players[tostring(host:get_peer(i))]
      if p then
        host:get_peer(i):send("fix " .. p:getConnectId())
      end
      i = i + 1
    end
    
    reconSent = true
  end
end

