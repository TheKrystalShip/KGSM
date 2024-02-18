All `*.service` files call `/home/[USER]/servers/[GAME]/start.sh` for starting up a game server.
Some of the `*.service` files have custom commands and settings in order to cater to whatever the game server needs when running or shutting down (Example: execute a world save before stopping).

Note that all servers have some important files:

- `start.sh` is called by the service file in order to start up the server. These files are created with specific configuration for each game. By having this file start up the game server with whatever config is needed, we avoid having to reload `systemctl` in order to detect changes done to the services. Just modify the `start.sh` file, save and you can immediately run `systemctl start [GAME].service`.

- Terraria & Project Zomboid have a `stop.sh` file which is used to issue commands to the running service because they require a world save before shutting down. They have an active socket where commands can be written to and passed to the service process in order to gracefully shut down.
All of this is handled by `systemctl` so there's no need to do anything from the coding side.

These sockets (`*.stdin`) are automatically opened/closed alongside the service thanks to https://unix.stackexchange.com/a/730423
