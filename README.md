# KGSM - Krystal Game Server Manager

KGSM is a simple and efficient tool for installing, updating, and managing game servers on Linux systems.

## Compatibility

KGSM is designed to work with `bash`, `systemd`, and optionally `ufw`.

Tested and developed on:

- `Manjaro 24.0.2 Wynsdey`
- `Kernel v6.5.13-7-MANJARO`
- `Bash 5.2.26`
- `systemd 256`
- `ufw 0.36.2`

While it aims for broad compatibility with minimal dependencies, functionality on other distributions is not guaranteed.

## Installation

### Download the Project

```sh
wget -qO - https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/installer.sh | sh
```

### Run the Project

Once downloaded, use `./kgsm.sh` as your entry point. Running it without arguments starts it in interactive mode.

For a description of menu options, run:

```sh
./kgsm.sh --interactive --help
```

To use named arguments for automation, run:

```sh
./kgsm.sh --help
```

### Requirements

To view a list of required dependencies, run:

```sh
./kgsm.sh --requirements
```

To attempt automatic installation of dependencies, run:

```sh
./kgsm.sh --requirements --install
```

- If [SteamCMD](https://developer.valvesoftware.com/wiki/SteamCMD) is not available through your distribution's package manager, you will need to manually set it up and ensure `steamcmd` is in the `$PATH`.

- (Optional) KGSM can integrate with [`UFW`](https://en.wikipedia.org/wiki/Uncomplicated_Firewall) if detected, but it is not required for usage.

## Configuration

On the first run, `./kgsm.sh` will create a `config.cfg` file. Review and modify this file as needed. It includes descriptions for each setting.

## Updating

To ensure you are using the latest version, run:

```sh
./kgsm.sh --update
```

## License

KGSM © 2024 by Cristian Moraru is licensed under CC BY-NC 4.0. To view a copy of this license, visit [Creative Commons](https://creativecommons.org/licenses/by-nc/4.0/).
