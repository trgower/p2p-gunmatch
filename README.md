# p2p-gunmatch
A small peer-to-peer top-down shooter game using Love2d. Requires an nat-traversal-server

## Peer-to-peer
This game uses a peer-to-peer lockstep. Each player will wait until they have recieved the command from each opposing player before "executing" the turn. Since internet packets(commands) don't travel instantly, a buffer will be required to prevent jitter. This buffer will store the commands in a buffer until they are ready to be executed. This will cause client side latency but it will keep every game state in sync.

The physics simulation will run at 60hz or around 16ms per step or turn. This means that if you have a max latency of 65ms in your game, you should set the buffer around 5 or 6 (65/16=4). If latency spikes above 65, you will experience jitter until it drops back down. The buffer does not once the game is started.

## Libraries/Framework
* [LÖVE](https://love2d.org/) - Love2d is an Open source 2d game programming framework
* [lua-enet](http://leafo.net/lua-enet/) - UDP networking
* [SUIT](suit.readthedocs.io/en/latest/) - Simple User Interface Toolkit for LOVE
* [Classic](https://github.com/rxi/classic) - Tiny class module for Lua

## Credits
[Kenney](http://kenney.nl/) for the Graphics
