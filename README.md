# KGSM - Krystal Game Server Manager

KGSM is a simple and efficient tool for installing, updating, and managing game
servers on Linux systems.

KGSM streamlines the setup of game servers and allows users to interact with them while maintaining a hands-off approach once the servers are created. By providing scripts for starting, stopping, and restarting game servers, KGSM eliminates the need for ongoing involvement.

## Compatibility

KGSM is designed to work with `bash`, `systemd`, and optionally `ufw`.

Tested and developed on:

- Manjaro 24.0.2 Wynsdey
- Kernel v6.5.13-7-MANJARO
- Bash 5.2.26
- systemd 256
- ufw 0.36.2

While it aims for broad compatibility with minimal dependencies, functionality
on other distributions is not guaranteed.

## Installation

### Requirements

The following packages are required in order to use KGSM:

```sh
grep jq wget unzip tar sed findutils steamcmd
```

- If [SteamCMD][1] is not
  available through your distribution's package manager, you will need to
  manually set it up and ensure `steamcmd` is available from the `$PATH`.

Optional:

```sh
systemd ufw
```

Both `systemd` and `ufw` can be enabled/disabled from the `config.ini` file

### Download the Project

```sh
wget -qO - https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/install.sh | sh
```

### Run the Project

Once downloaded, use `./kgsm.sh` as your entry point. Running it without
arguments starts it in interactive mode.

For a description of menu options, run:

```sh
./kgsm.sh --interactive --help
```

To use named arguments for automation, run:

```sh
./kgsm.sh --help
```

## Configuration

On the first run, `./kgsm.sh` will create a `config.ini` file. Review and modify
this file as needed. It includes descriptions for each setting.

## Updating

To ensure you are using the latest version, run:

```sh
./kgsm.sh --update
```

## License

KGSM is licensed under the terms of GPL-3.0, check the [LICENSE](LICENSE) file
for more information.

[1]: https://developer.valvesoftware.com/wiki/SteamCMD
[2]: https://en.wikipedia.org/wiki/Uncomplicated_Firewall
