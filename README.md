# KGSM - Krystal Game Server Manager

A simplistic one-stop-shop management interface for installing, updating and managing game servers on Linux based systems.

## Compatibility

KGSM has been developed and tested on `Manjaro 24.0.2 Wynsdey`, `Kernel v6.5.13-7-MANJARO`, using `Bash 5.2.26` I cannot guarantee it will work flawlessly with other distributions but the project aims for broad compatibility by using as few dependencies as possible.

## Installation

### Download the project

```sh
wget -O "kgsm.tar.gz" https://github.com/TheKrystalShip/KGSM/archive/refs/heads/main.tar.gz
```
```sh
tar -xzf "kgsm.tar.gz"
```
```sh
cd ./KGSM-main
```
```sh
chmod +x ./kgsm.sh ./modules/*.sh
```

### Updating

KGSM comes with built-in updating capabilities.

Ensure you're using the latest version by running
```sh
./kgsm.sh --update
```

### Requirements

#### Packages

To see a list of required dependencies you can run:

```sh
./kgsm.sh --requirements
```

To _attempt_ to automatically install dependencies, run:

```sh
./kgsm.sh --install-requirements
```

- If [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) isn't directly available through your distribution's package manager you will have to manually set it up and ensure `steamcmd` is available in the $PATH.

- (Optional) KGSM is set up to work with [`UFW`](https://en.wikipedia.org/wiki/Uncomplicated_Firewall) if it detects it on the system, but it's not required in order to use.

#### Environmental vars

For Steam games that require an account, `STEAM_USERNAME` & `STEAM_PASSWORD` environmental variables must be set.

- (Optional) `KGSM_DEFAULT_INSTALL_DIR` can also be set as a default installation directory to avoid being prompted on every install.

KGSM will source `/etc/environment` if it can't find some of the required environmental variables when running, a warning will be displayed in that case.

### Run the project

Once downloaded, `./kgsm.sh` is your entrypoint.

Use `./kgsm.sh --help` for a detailed description of all available commands.

## LICENSE

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit https://creativecommons.org/licenses/by-nc/4.0/
