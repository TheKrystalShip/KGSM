# Manual service installation

Everything `kgsm.sh` does can also be done by manually calling the individual
modules in the correct order. However, the variable `KGSM_ROOT` must be defined
and pointing to wherever `kgsm.sh` is located in order to use the modules by
themselves since there's a lot of sourcing between scripts.

Each module checks if `KGSM_ROOT` has been defined, otherwise they will error
out. They will also check if `config.ini` has been loaded already, and they will
load it if not.

All modules accept a `--help` arguement that will show a description of all
accepted arguments and their descriptions

Here's an example what `./kgsm --install factorio --install-dir /opt/test`
breaks down into:

## 1. Locate blueprint file

The **.bp** extension is optional when specifying a blueprint

It will search in the `blueprints` directory for a matching name and if none is
found, it will look in `blueprints/default`.

Note: You don't have to use the full path to a blueprint file, just the name of
the blueprint file with or without the **.bp** extension is enough, the modules
will search for the blueprint file based on the name, they don't expect a full
path.

## 2. Fetch the latest version available

```sh
latest_version=$(./modules/version.sh --blueprint factorio --latest)
```

It will internally account for any existing `[blueprint].overrides.sh`

## 3. Generate new instance config file

```sh
instance_config=$(./modules/instance.sh --create factorio --install-dir /opt)
```

This will return the absolute path to the instance config file which is needed
to proceed

## 4. Generate directory structurea

```sh
./modules/directories.sh -i $instance_config --install
```

## 5. Generate required files to run the service

```sh
sudo ./modules/files.sh -i $instance_config --install
```

Root permissions are needed for systemd and ufw

It will generate a `[instance].manage.sh` file inside the install directory
that's used to start/stop/restart and interact with the service socket for input
(if the service has an interactive console)

If any `[blueprint].overrides.sh` file exists in the `overrides` directory, it
will also be copied to the instance install directory.

If `USE_SYSTEMD=1` then it will also generate the required `[instance].service`
and `[instance].socket` files inside `SYSTEMD_DIR` and let systemd manage
startup/shutdown

If `USE_UFW=1` it will create and enable the ufw firewall rule file in
`UFW_RULES_DIR`

## 6. Run the download process

```sh
./modules/download.sh -i $instance_config
```

It will internally account for any existing `[blueprint].overrides.sh`

This will download everything into `INSTANCE_TEMP_DIR` without disrupting any
existing installation

## 7. Run the deployment process

```sh
./modules/deploy.sh -i $instance_config
```

It will internally account for any existing `[blueprint].overrides.sh`

This will move everything from `INSTANCE_TEMP_DIR` into `INSTANCE_INSTALL_DIR`
and it will prompt for confirmation if `INSTANCE_INSTALL_DIR` is not empty.

## 8. Save the version

```sh
./modules/version.sh --blueprint factorio --save $latest_version
```

And with that, the installation is complete

If it's set to run with systemd, it can be started using:

```sh
sudo systemctl start [instance].service
```

This will internally simply call the `[instance].manage.sh` with the `--start`
argument If systemd is not used, tmux can also be used, starting the service by
calling:

```sh
cd install_dir/[instance]
./[instance].manage.sh --start
```
