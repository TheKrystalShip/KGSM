# KGSM - Krystal Game Server Manager

A collection of bash scripts used to automate the creation/installation/updating/backups and management of game servers on Linux

## Requirements

- Packages: `grep` `python3` `wget` `unzip` `curl` `tar` `sed`

- [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD)

- `KGSM_ROOT` environmental variable needs to be set, pointing to the directory where `kgsm.sh` is located. Example: `KGSM_ROOT=/opt/kgsm` / `KGSM_ROOT=/home/myuser/servers`

- For Steam games that require an account, `STEAM_USERNAME` & `STEAM_PASSWORD` environmental variables must be set.

### Optional:

- `KGSM_DEFAULT_INSTALL_DIR` can also be set as a main installation directory to avoid being prompted on every install.

- `KGSM_RABBITMQ_URI` & `KGSM_RABBITMQ_ROUTING_KEY` can be used to send events when services are installed/uninstalled

## Workflow

Game servers are built from blueprint files (`/blueprints/*.bp`) and optionally override scripts (`/overrides/*.overrides.sh`)

The main `kgsm.sh` script file provides a `--help` command that explains how each option works.

# LICENSE

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit https://creativecommons.org/licenses/by-nc/4.0/
