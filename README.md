# KGSM - Krystal Game Server Manager

A simple, efficient and portable command-line tool for installing, updating,
and managing game servers on Linux systems.

KGSM streamlines the setup of game servers by providing all the necessary
scripts for managing their lifecycle without the need for ongoing involvment
post-creation.

## Compatibility

KGSM is designed to work with `bash`, and optionally `systemd` and `ufw`.

Tested and developed on:

- Manjaro 24.0.2 Wynsdey
- Kernel v6.5.13-7-MANJARO
- Bash 5.2.26
- systemd 256
- ufw 0.36.2

While it aims for broad compatibility with minimal dependencies, functionality
on other distributions is not guaranteed.

## Requirements

The following packages are required in order to use KGSM:

```sh
grep jq wget unzip tar sed coreutils findutils steamcmd
```

> [!NOTE]
>
> If [SteamCMD][1] is not
> available through your distribution's package manager, you will need to
> manually set it up and ensure `steamcmd` is available from the `$PATH`.

Optionally, KGSM can integrate with `systemd` and `ufw` with a simple
configuration toggle.

## Download

There's a few options on how to get the software:

Either clone the repository using `git`, download the latest [Release][3]
available or use the install script by running the following command:

```sh
wget -qO - https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/install.sh | sh
```

The installation is fully contained to the subdirectory KGSM creates.

## How to use

### Run the Project

Once downloaded, run `./kgsm.sh`. This will create a `config.ini` file with
default values in the same directory. Review and modify this file as needed.

After that, running `./kgsm.sh` will start it in interactive mode where you'll
be presented with a menu of different actions to choose from.

For a description of each menu option you can either pick the `Help` option in
the menu, or run `./kgsm.sh` with the following arguments:

```sh
./kgsm.sh --help --interactive
```

For automation, KGSM accepts named arguments for all operations.
To see a descriptive list of the named arguments, run:

```sh
./kgsm.sh --help
```

For a more in-depth explanation on the different features and how to use them,
please check the [Documentation][4]

## Updating

KGSM comes with built-in updating capabilities.
In order to update to the latest version, run:

```sh
./kgsm.sh --update
```

Alternatively in case of emergencies or accidental lose of critical files, you
can _attempt_ to repair the install by running:

```sh
./kgsm.sh --update --force
```

This will re-download all KGSM specific files, any blueprint overrides you
might have will be preserved.

## License

KGSM is licensed under the terms of GPL-3.0, check the [LICENSE](LICENSE) file
for more information.

[1]: https://developer.valvesoftware.com/wiki/SteamCMD
[2]: https://en.wikipedia.org/wiki/Uncomplicated_Firewall
[3]: https://github.com/TheKrystalShip/KGSM/releases
[4]: https://github.com/TheKrystalShip/KGSM/tree/main/docs
