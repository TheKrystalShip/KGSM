# Managing game servers

This document servers to explain how to manage a game server post-installation.

> [!NOTE]
>
> \<instance> represents the generated name of an instance config file
> post-installation

## Startup

Now in order to start up the instance there's a few different options:

### Option 1: Using KGSM

There's built-in functionality into KGSM to manage instances, it's not
_required_ to use KGSM to do it, it just provides the option.

Using the interactive mode, select the `Start` option in the menu.
You will be prompted to select an instance to start up.

Alternatively the named arguments option:

```sh
./kgsm --instance <instance> --start
```

> [!NOTE]
> You can see all created instances by either selecting `List instances` from
> the interactive mode menu, or by running:
>
> ```sh
> ./kgsm.sh --instances
> ```

### Option 2: Systemctl

If `USE_SYSTEMD` is enabled in the `config.ini` file, then the instance will
have been configured to run using `systemctl`.

Example commands:

```sh
sudo systemctl start <instance>
```

### Option 3: Manually

Alternatively if `USE_SYSTEMD` is not enabled in `config.ini`, then it's up to
the user to manage the instance manually.
Each instance provides a `<instance>.manage.sh` entrypoint that will start/stop
the game server and serve as a command input for the interactive console if the
game server has one.

The `<instance>.manage.sh` file will be located in the instance's installation
directory.

To start the instance in the current terminal, run:

```sh
./<instance>.manage.sh --start
```

To start the instance as a background process and detach it from the current
terminal, run:

```sh
./<instance>.manage.sh --start --background
```

To see all options, run:

```sh
./<instance>.manage.sh --help
```

### Automatic start on boot

#### Systemctl

For instances created with `USE_SYSTEMD` enabled in `config.ini`, you can enable
automatic startup on system boot through `systemctl` with the following command:

```sh
sudo systemctl enable <instance>
```

#### Manually

The user will have to manually handle automatic startup on boot by adding the
following to their startup script:

```sh
/full/path/to/instance/<instance>.manage.sh --start --background
```

## Shutdown

### Option 1: Using KGSM

From the interactive mode menu, select the `Stop` option and choose an instance
when prompted. This will shut down the instance.

### Option 2: Systemctl

```sh
sudo systemctl stop <instance>
```

### Option 3: Manually

> [!Note]
> Applicable when the instance has been started with the `--start --background`
> arguments

Navigate to the instance's installation directory and run:

```sh
./<instance>.manage.sh --stop
```
