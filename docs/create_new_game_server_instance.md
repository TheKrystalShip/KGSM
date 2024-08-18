# Creating a new game server instance

This document assumes you've read [Blueprints 101](blueprints.md) and
[Instances 101](instances.md). If you haven't, please do so before proceeding.

## Option 1: KGSM - Named arguments

The full command to create an instance of a blueprint is:

> [!NOTE]
> If you have `INSTANCE_DEFAULT_INSTALL_DIR` set in the `config.ini` file
> then `--install-dir <directory>` is not needed.

```sh
./kgsm.sh --install <blueprint> [--install-dir <directory>]
```

- `<blueprint>` is the name of a blueprint file that's located in the
  `blueprints` directory or in the `blueprints/default` directory.
  It's not required to add the **.bp** extension.

- `<directory>` is an absolute path to a directory where you have write
  permissions to. KGSM will create a subdirectory in there with the name of the
  new instance.

## Option 2: KGSM - Interactive mode

Run KGSM in interactive mode:

```sh
./kgsm.sh
```

From the options menu, choose the `Install` option.

You will be prompted to choose a blueprint for installation.

If you don't have `INSTANCE_DEFAULT_INSTALL_DIR` set in the `config.ini` file,
you will be prompted to provide an installation directory.

## Option 3: Manual instance creation

Everything `kgsm.sh` does can also be done by manually calling the individual
modules in the correct order. However, the variable `KGSM_ROOT` must be defined
and pointing to the directory where `kgsm.sh` is located in order to use the
modules by themselves since there's a lot of sourcing between scripts.

Each module checks if `KGSM_ROOT` has been defined, otherwise they will error
out. They will also check if `config.ini` has been loaded already, and they will
load it if not.

All modules accept a `--help` argument that will show a description of all
accepted arguments and their descriptions

Here's an example what `./kgsm --install factorio --install-dir /opt/test`
breaks down into:

### 1. Choose blueprint file

Choose a blueprint from either the `blueprints/default` or `blueprints`
directory to install.
You'll have to provide the name of the blueprint file in the following step.

> [!NOTE]
> The **.bp** extension is not required

### 2. Generate new instance config file

```sh
instance_config=$(./modules/instances.sh --create factorio --install-dir /opt/test)
```

This will provide the name of the instance config file required by the next
steps.

### 3. Generate directory structure

```sh
./modules/directories.sh -i $instance_config --create
```

### 4. Generate required files to run the service

```sh
./modules/files.sh -i $instance_config --create
```

KGSM will generate a `<instance>.manage.sh` file inside the install directory
that's used to start/stop/restart and interact with the service socket for input
(if the service has an interactive console)

If any `[blueprint].overrides.sh` file exists in the `overrides` directory, it
will also be copied to the instance install directory.

If `USE_SYSTEMD` is enabled in `config.ini` then it will also generate the
required `<instance>.service` and `<instance>.socket` files inside
`SYSTEMD_DIR` and let `systemd` manage startup/shutdown.

If `USE_UFW` is enabled in `config.ini` it will create and enable the ufw
firewall rule file in `UFW_RULES_DIR`.

> [!NOTE]
>
> Root permissions are needed if `USE_SYSTEMD` or `USE_UFW` integration is
> enabled in `config.ini`. The script will prompt for password if/when needed.

### 5. Fetch the latest version available

```sh
latest_version=$(./modules/version.sh -i $instance_config --latest)
```

KGSM will internally account for any existing `[blueprint].overrides.sh`

### 6. Run the download process

```sh
./modules/download.sh -i $instance_config
```

KGSM will internally account for any existing `[blueprint].overrides.sh`

This will download everything into `INSTANCE_TEMP_DIR` without disrupting any
existing installation

### 7. Run the deployment process

```sh
./modules/deploy.sh -i $instance_config
```

KGSM will internally account for any existing `[blueprint].overrides.sh`

This will move everything from `INSTANCE_TEMP_DIR` into `INSTANCE_INSTALL_DIR`
and it will prompt for confirmation if `INSTANCE_INSTALL_DIR` is not empty.

### 8. Save the version

```sh
./modules/version.sh -i $instance_config --save $latest_version
```

### 9. Done

And with that, the installation is complete.
