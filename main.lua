require "enet"
require "player"
local suit = require "suit"

local address, port = "127.0.0.1", 34567
local host = enet.host_create()
local status = "Status: loading..."
local server = host:connect(address..":"..port) -- Queue connect to the server
local event = host:service(100) -- Send queued packets

local leftBtnText = "Host"
local rightBtnText = "Join"
local hosting = false
local joined = false
local ready = false

local input = {text = ""}

function love.load()
  -- Allows the user to hold down a key to simulate repeated key presses
  love.keyboard.setKeyRepeat(true)
  
  if event and (event.type == "connect") then
    status = "Status: connected"
  else
    status = "Status: not connected"
  end
  
  player = Player()
  
end

function love.update(dt)
  -- Wait at most 16ms for an event (packet)
  event = host:service(16)
  
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
    else                          -- click Host
      hosting = true
      joined = true
      ready = true
      leftBtnText = "Leave"
      rightBtnText = "Start"
    end
  end
  
  -- The right button is set in the layout in a column to the right of
  -- the last element placed. The label and function also changes, but 
  -- has 4 states instead of 2.
  if suit.Button(rightBtnText, suit.layout:col(98, 30)).hit then
    if not joined then            -- click Join
      joined = true
      rightBtnText = "Ready"
      leftBtnText = "Leave"
    elseif hosting then           -- click Start
      print("start")
    elseif not ready then         -- click Ready
      ready = true
      rightBtnText = "Unready"
    else                          -- click Unready
      ready = false
      rightBtnText = "Ready"
    end
  end
  
  -- This re-sets the layout in another spot with the same padding. 
  -- This allows us to set other elements regardless of the previous
  -- element placed. It effectively create another layout.
  suit.layout:reset(156, 375, 4, 4)
  suit.Label(status, suit.layout:row(200, 30))
  
  player:updateMouse(love.mouse.getPosition())
  player:update(dt)
  
end -- update(dt)

function love.draw()
  suit.draw()
  player:draw()
end

function love.textinput(t)
  suit.textinput(t)
end

function love.keypressed(key)
  suit.keypressed(key)
  
  if (key == "up") or (key == "w") then
    player:keyDown(3)
  elseif (key == "left") or (key == "a") then
    player:keyDown(2)
  elseif (key == "down") or (key == "s") then
    player:keyDown(1)
  elseif (key == "right") or (key == "d") then
    player:keyDown(0)
  end
end

function love.keyreleased(key)
  if (key == "up") or (key == "w") then
    player:keyUp(3)
  elseif (key == "left") or (key == "a") then
    player:keyUp(2)
  elseif (key == "down") or (key == "s") then
    player:keyUp(1)
  elseif (key == "right") or (key == "d") then
    player:keyUp(0)
  end
end

