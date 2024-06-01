# KGSM - Krystal Game Server Manager

A collection of bash scripts used to automate the creation/installation/updating/backups and management of game servers on Linux

## Requirements

- Packages: `grep` `python3` `wget` `unzip` `curl` `tar` `sed`

- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)

- `KGSM_ROOT` environmental variable needs to be set, pointing to the directory where `kgsm.sh` is located. Example: `KGSM_ROOT=/opt/kgsm` / `KGSM_ROOT=/home/myuser/servers`

- For Steam games that require an account, `STEAM_USERNAME` & `STEAM_PASSWORD` environmental variables must be set.

## Workflow

Game servers are built from blueprint files (`/blueprints/*.bp`) and optionally override scripts (`/overrides/*.overrides.sh`)

The blueprint file is the source of configuration for the game servers, meaning all configuration will be read from there and scaffolded further.
Check the existing blueprints for working examples.

The `/scripts/create_from_blueprint.sh [BLUEPRINT_NAME]` script will take a blueprint and scaffold all the necessary directories & files needed for a game server.

# LICENSE

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit https://creativecommons.org/licenses/by-nc/4.0/
