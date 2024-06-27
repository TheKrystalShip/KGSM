# KGSM - Krystal Game Server Manager

A collection of bash scripts used to automate the creation/installation/updating/backups and management of game servers on Linux.

Running the main `kgsm.sh` script with no arguments will start it in interactive mode, otherwise use `kgsm.sh --help` to see available commands.

## Compatibility

KGSM has been developed and tested only on `Manjaro 24.0.2 Wynsdey`, `Kernel v6.5.13-7-MANJARO`, I cannot guarantee full compatibility with other distributions but compatibility and code simplicity was a major consideration during the development process.

## Requirements

### Packages:

- Run `./kgsm.sh --install-requirements` in order to check all necessary packages are available or if any need installation.

- If [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) isn't directly available through your distribution's package manager you will have to manually set it up and ensure `steamcmd` is available in the $PATH.

- (Optional) KGSM is set up to work with `ufw` if it detects it on the system, but it's not required in order to use.

### Environmental vars

KGSM will expect env vars to be available when running the script, otherwise it will manually load `/etc/environment` as a fallback.

- For running any of the script under the `./scripts/*` directory, `KGSM_ROOT` environmental variable needs to be set pointing to the directory where `kgsm.sh` is located.

- Running `kgsm.sh` by itself doesn't _require_ `KGSM_ROOT` to be set, but it is recommended.

  - Example: `KGSM_ROOT=/opt/kgsm`

- For Steam games that require an account, `STEAM_USERNAME` & `STEAM_PASSWORD` environmental variables must be set.

- (Optional) `KGSM_DEFAULT_INSTALL_DIR` can also be set as a main installation directory to avoid being prompted on every install.
  - Example: `KGSM_DEFAULT_INSTALL_DIR=/home/myuser/servers`

# LICENSE

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit https://creativecommons.org/licenses/by-nc/4.0/
