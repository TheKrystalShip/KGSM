# Managing Game Servers

This document explains how to manage a game server post-installation using KGSM.

> [!NOTE]
> `<instance>` represents the generated name of an instance configuration file post-installation.

---

## Startup

To start a game server instance, you can choose from several methods:

### Option 1: Using KGSM

KGSM provides built-in functionality for managing instances. While not mandatory, it simplifies the process.

#### Interactive Mode

Run KGSM in interactive mode, then select the `Start` option in the menu. You will be prompted to select an instance to start.

#### Named Arguments

Use the following command:

```sh
./kgsm.sh --instance <instance> --start
```

> [!NOTE]
> To list all created instances, either select `List instances` in interactive mode or run:
>
> ```sh
> ./kgsm.sh --instances
> ```

### Option 2: Systemctl

If `USE_SYSTEMD` is enabled in `config.ini`, the instance will be configured to run as a `systemctl` service.

Example command:

```sh
sudo systemctl start <instance>
```

### Option 3: Manually

If `USE_SYSTEMD` is not enabled, you can manage the instance manually using the `<instance>.manage.sh` script in the instance’s installation directory.

To start the instance in the current terminal, run:

```sh
./<instance>.manage.sh --start
```

To start the instance as a background process, run:

```sh
./<instance>.manage.sh --start --background
```

To see all options, run:

```sh
./<instance>.manage.sh --help
```

---

## Restart

To restart a game server instance:

### Using KGSM

```sh
./kgsm.sh --instance <instance> --restart
```

### Using Systemctl

```sh
sudo systemctl restart <instance>
```

### Manually

Navigate to the instance’s installation directory and run:

```sh
./<instance>.manage.sh --restart
```

---

## Status Checks

To check the status of a game server instance:

### Using KGSM

```sh
./kgsm.sh --instance <instance> --status
```

### Using Systemctl

```sh
sudo systemctl status <instance>
```

---

## Logs

To view logs for a game server instance, KGSM provides a dedicated command:

```sh
./kgsm.sh --instance <instance> --logs
```

This command automatically retrieves logs from:

- `journalctl` if the instance is managed by `systemctl`.
- The instance’s log file if `systemctl` integration is not enabled.

---

## Automatic Start on Boot

### Systemctl

For instances created with `USE_SYSTEMD` enabled, enable automatic startup on boot using:

```sh
sudo systemctl enable <instance>
```

### Manually

If `USE_SYSTEMD` is not enabled, add the following line to your system’s startup script:

```sh
/full/path/to/instance/<instance>.manage.sh --start --background
```

---

## Shutdown

To shut down a game server instance:

### Option 1: Using KGSM

From the interactive mode menu, select the `Stop` option and choose an instance when prompted. Alternatively, use:

```sh
./kgsm.sh --instance <instance> --stop
```

### Option 2: Systemctl

```sh
sudo systemctl stop <instance>
```

### Option 3: Manually

Navigate to the instance’s installation directory and run:

```sh
./<instance>.manage.sh --stop
```

> [!NOTE]
> This will stop the instance if it's running as a background process.

---

## Decommissioning Game Servers

To completely remove a game server instance, use KGSM’s uninstall command:

```sh
./kgsm.sh --uninstall <instance>
```

This will:

- Stop the instance.
- Remove all files and directories associated with the instance.
- Delete `systemd` and `ufw` integrations, if applicable.


