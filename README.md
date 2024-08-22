# KGSM - Krystal Game Server Manager

Welcome! This is your go-to tool for setting up and managing game
servers on Linux. If you're looking for a simple solution for setting up a few
game servers, this is it. It takes care of the heavy lifting so you can focus
on what really matters—playing games with your friends.

KGSM makes it easy to install, update, and manage your game servers with minimal
hassle. It's designed to be simple, efficient, and portable, perfect for someone
who wants a quick and easy solution without having to spend hours reading
documentation or watching tutorials.

## Will it work for me?

As much as I'd like for KGSM to work on every system, unfortunately I don't have
that much free time to test everywhere and fix all the potential differences
between distributions.

I've developed and tested on the following:

- Manjaro 25.0.2 Wydnesdey
- Kernel v6.5.13-7-MANJARO
- Bash 5.2.26
- Systemd 256
- Ufw 0.36.2

In _theory_ it should work on most GNU/Linux systems as long as the dependencies
are met.

## What You'll Need

Before diving in, make sure your system has the following packages:

```sh
grep jq wget unzip tar sed coreutils findutils steamcmd
```

> [!NOTE]
>
> If [SteamCMD][1] isn't available through your distro’s package manager, you'll
> need to set it up manually.

For an even smoother experience, you can integrate KGSM with `systemd` and
[`ufw`][2] with just a few configuration tweaks.

## Getting Started

There are a few ways to grab KGSM:

1. Clone the repository using `git`
2. Download the latest [Release][3]
3. Use this handy install script:

```sh
wget -qO - https://raw.githubusercontent.com/TheKrystalShip/KGSM/main/install.sh | bash
```

Everything will be contained in a subdirectory KGSM creates, keeping your
system clean and organized.

## How to Use KGSM

Once you've got KGSM, running it is simple. Just execute:

```sh
./kgsm.sh
```

The first time you run it, KGSM will create a `config.ini` file with default
settings. Feel free to tweak this file to suit your needs. After that,
running it again will take you into an interactive menu where you can choose
what to do.

Need help? Either select the `Help` option in the menu or run:

```sh
./kgsm.sh --help --interactive
```

For those who love automation, KGSM supports named arguments for all its
operations. For a full list of options just run:

```sh
./kgsm.sh --help
```

There's also [Documentation][4] for the project which explains how KGSM operates
in case you need it.

## Keeping Up-to-Date

Updating KGSM is a breeze. Just run:

```sh
./kgsm.sh --update
```

In case you run into issues or lose any files, you can try a repair with:

```sh
./kgsm.sh --update --force
```

This will re-download all the KGSM-specific files while preserving your custom
settings.

## License

KGSM is licensed under the terms of GPL-3.0, check the [LICENSE](LICENSE) file
for more information.

[1]: https://developer.valvesoftware.com/wiki/SteamCMD
[2]: https://en.wikipedia.org/wiki/Uncomplicated_Firewall
[3]: https://github.com/TheKrystalShip/KGSM/releases
[4]: https://github.com/TheKrystalShip/KGSM/tree/main/docs
