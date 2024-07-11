# KGSM - Krystal Game Server Manager

A simplistic one-stop-shop management interface for installing, updating and managing game servers on Linux based systems.

## Compatibility

KGSM is programmed to be used with `bash`, `systemd` and optionally `ufw`.

It's been developed and tested on `Manjaro 24.0.2 Wynsdey`, `Kernel v6.5.13-7-MANJARO`, using `Bash 5.2.26`, `systemd 256` and `ufw 0.36.2`.

I cannot guarantee it will work flawlessly with other distributions but the project aims for broad compatibility by using as few dependencies as possible.

## Installation

### Download the project

```sh
wget -qO - https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/installer.sh | sh
```

### Run the project

Once downloaded, `./kgsm.sh` is your entrypoint. Running it with no arguments will start it in interactive mode.

Use `./kgsm.sh --interactive --help` for a description of the menu options.

Alternativelly `./kgsm.sh` accepts named arguments in order to allow automation, run `./kgsm.sh --help` for a detailed description of all available named commands.

### Configuration

On first run, `./kgsm.sh` will create a new `config.cfg` file, check that file and modify any settings needed.

The file contains descriptions for each setting.

### Updating

KGSM comes with built-in updating capabilities.

Ensure you're using the latest version by running:

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

## LICENSE

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit https://creativecommons.org/licenses/by-nc/4.0/
