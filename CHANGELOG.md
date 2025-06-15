# Changelog

- [Changelog](#changelog)
  - [Ideas for the future](#ideas-for-the-future)
  - [Work in progress](#work-in-progress)
  - [2.0](#20)
  - [1.7.3](#173)
  - [1.7.2](#172)
  - [1.7.1](#171)
  - [1.7.0 - Maintenance Update](#170---maintenance-update)
  - [1.6.1](#161)
  - [1.6.0 - Events](#160---events)
  - [1.5.2](#152)
  - [1.5.1](#151)
  - [1.5.0](#150)
  - [1.4.2](#142)
  - [1.4.1](#141)
  - [1.4.0](#140)
  - [1.3.2](#132)
  - [1.3.1](#131)
  - [1.3.0](#130)
  - [1.2.7](#127)
  - [1.2.6](#126)
  - [1.2.5](#125)
  - [1.2.4](#124)
  - [1.2.3](#123)
  - [1.2.1](#121)
  - [1.2.0](#120)
  - [1.1.1](#111)
  - [1.1.0](#110)
  - [1.0.4](#104)
  - [1.0.3](#103)
  - [1.0.2](#102)
  - [1.0.1](#101)
  - [1.0.0](#100)

## Ideas for the future

Features that I'd like to consider implementing in order to make KGSM more versatile.

- Support for other firewalls other than UFW
- Allow instances to start automatically on system boot without going through systemd
- Podman as an alternative for Docker
- More game servers

## Work in progress

- Bug fixing after version 2.0

## 2.0

This is a major version release and is not compatible with previous versions of KGSM.

> It is highly recommended to use a fresh start with KGSM 2.0 to avoid compatibility issues.

A migration module has been introduced to help transition existing instances from v1.* to v2.0:

```sh
./kgsm.sh --migrate
```

> [!WARNING]
> This will convert all instance configuration files to the new format and regenerate all `<instance>.manage.sh` files to make them standalone.
> This is necessary as KGSM now delegates actions to each instance's management file.
> 
> **Back up your important files/servers before migration.**

Version 2.0 represents a comprehensive core rewrite to support the following new features:

**Standalone Instances**

- Each instance receives its own self-sufficient `<instance>.manage.sh` script
- Instances function independently, handling server operations, backups, updates, and management
- Optional symbolic links in system `$PATH` enable global access
- KGSM is only needed for initial setup, not ongoing operations

**Container-based Blueprints**

- Full support for container-based instances alongside native deployments
- Curated images available in the [KGSM-Containers](https://github.com/TheKrystalShip/KGSM-Containers) repository
- Feature parity with native instances
- Requires `docker` and `docker-compose`

**UPnP Support**

- Automatic port forwarding configuration, configurable per instance

**Breaking Changes**

- New instance configuration file format (requires migration)
- Blueprints reorganized into subdirectories (`custom/default` and `container/native`)
- New blueprint format (custom blueprints require manual migration)
- Command syntax changed: `--install/--id` replaced with `--create/--name`
- Updated config.ini format
- Renamed override functions (see overrides.tp for new names)
- Log command behavior changed: `--logs` shows last 10 lines; `--logs --follow` for continuous output

## 1.7.3

**Bug fixes**
- `installer.sh` failed to store the new version after updating KGSM.

## 1.7.2

**Bug fixes**
- Removed warning messages from `installer.sh` as they were interfering with the `--version` argument output.

## 1.7.1
- `version.txt` has been added back to repository to allow previous versions of KGSM to update correctly since they are reliant on that file. However, past `1.7.0`, the file is not needed or used for anything and will be automatically handled by `installer.sh` whenever it's called.

**Bug fixes**
- Incorrect function call in `kgsm.sh` for the `--update-config` flag.

## 1.7.0 - Maintenance Update  

This release focuses on improving internal code quality and enhancing debugging capabilities to make troubleshooting easier. The introduction of standardized exit codes across all scripts allows for better error identification, while the newly implemented logging system enables persistent tracking of operations.  
 
- **Descriptive exit codes**: Implemented across all modules to provide clear information about errors and their causes.  
- **Logging**: KGSM and its modules can now write operation logs to a file if enabled in `config.ini`.  
- **Update checker**: Added the `./kgsm.sh --check-update` command to verify if a new version is available.  
- **Contributor guide**: A `CONTRIBUTING.md` file has been added to the repository to assist contributors.  
- **Force kill game server**: `[instance].manage.sh` includes a new `--kill` argument to terminate unresponsive game servers. This is used internally by the `[instance].manage.sh` file in conjunction with a timeout mechanism during the normal `--stop` procedure.
- **Instance activity check**: `[instance].manage.sh` now includes a `--is-active` flag to verify if a game server is running. This is called internally by `modules/instances.sh` for more accurate status reporting.  
- **Template update**: The `manage.tp` template has been updated to include the `--kill` flag for newly created instances.  

To apply the new `[instance].manage.sh` changes to existing instances, run:  
```sh  
./modules/files.sh -i [instance] --create --manage  
```  
 
- **Environment simplification**: Modules no longer require `KGSM_ROOT` to be set before execution.  
- **Installer consolidation**: The `installer.sh` script now handles installation, version control, and updates. Update-related tasks can be accessed through `kgsm.sh`, eliminating the need to call `installer.sh` directly.  
- **Codebase refactoring**: `modules/include/common.sh` has been split into sub-modules to improve code organization and responsibility separation.  
- **Versioning improvements**:  
  - The `version.txt` file has been replaced with `.kgsm.version`.  
  - KGSM versions now align with GitHub Releases instead of relying on a repository file.  

**Bug fixes**
- **.editorconfig corrections**: Fixed incorrect `indent_style` settings for some file types.  

## 1.6.1
- New `--update-config` parameter for `kgsm.sh` to merge new options added to `config.default.ini` to user defined `config.ini`.
- `config.default.ini` options are now a bit better organized

**Bug fixes**
- `modules/instances.sh` now reflects the correct default value for `INSTANCE_RANDOM_CHAR_COUNT` for the instance ID generation.

## 1.6.0 - Events

Events provide a mechanism for KGSM to communicate with other processes while remaining completely standalone and lightweight. By using a Unix Domain Socket for inter-process communication (IPC), KGSM can emit events for various actions happening under the hood. This enables other processes, like [KGSM-Bot](https://github.com/TheKrystalShip/KGSM-Bot), to listen, interpret, and react to these events.

Leveraging KGSM as the source of truth allows dependent processes to operate with minimal configuration, focusing solely on reacting to the incoming data.


- Unix Domain Socket support for IPC.
- New configurable option in `config.default.ini` to enable/disable events and set the socket path. Make sure to add the new configuration to your own `config.ini` file to enable events.
- New module: `modules/include/events.sh`.
- Event emissions for all major stages and actions, from instance creation to removal, formatted as JSON using the existing jq dependency.
- Optional `--json` argument for `modules/instances.sh` and `modules/blueprints.sh` to display information in JSON format. Documented in the `--help` command for both modules and the `kgsm.sh --help` documentation.
- Optional `KGSM_BRANCH=` option in `config.default.ini` allowing you to update KGSM from either the `main` development branch or the `dev` testing branch.

**Bug fixes**
- Corrected missing colored output in several modules.

## 1.5.2

**Bug fixes**
- Instances with systemd as a lifecycle manager were not getting logs followed.

## 1.5.1

**Bug fixes**
- Wrong argument order in `modules/instances.sh` for `--logs`.

## 1.5.0
**Breaking changes**
- `kgsm.sh --instances` now prints a list of instances without the .ini extension
- `kgsm.sh -i X --logs` will now follow rotating logs automatically, however the `--follow` flag has been removed and it will now always follow logs.


- Colored output! Commands will now display a message [SUCCESS / INFO / WARNING / ERROR] in color if the output supports it.
- Changelog: `kgsm.sh --update` will (going forward) show a list of commits and their messages between whatever version you have locally and whichever is the newest available after updating.
- Unturned dedicated server blueprint
- Silenced Factorio output on deployment
- Optimized internal `find` calls slightly

## 1.4.2

**Bug fixes**
- - `modules/instances.sh` was not properly accounting for `systemd` as a lifecycle manager, meaning the `--input` argument was sent to systemd which errored out.

## 1.4.1

**Bug fixes**
- Added missing internal `--debug` flag to a few module calls.

## 1.4.0
- New named argument: `./kgsm.sh --instance <instance> --save`, issues the save command to the instance if the instance has an interactive console and the $INSTANCE_SAVE_COMMAND is set.
- New named argument: `./kgsm.sh --instance <instance> --input <command>`, allows issuing ad-hoc commands to the instance if the instance has an interactive console.

These new features are currently **not** available for the interactive mode, they will be added at a later point.

## 1.3.2
- `kgsm.sh` now exposes an additional named argument for listing available backups for an instance. This was available in interactive mode but didn't have parity with the named arguments, now it does.

```sh
./kgsm.sh -i <instance> --backups
```
## 1.3.1

**Bug fixes**
- `modules/deploy.sh` now recursively copies and force overwrites the content of `$INSTANCE_INSTALL_DIR` with the contents of `$INSTANCE_TEMP_DIR`. The lack of force overwrite was causing the update process to fail for some game servers.

## 1.3.0

**Breaking** - Changed modules/instances.sh to use the `--id` argument as the full name of the instance instead of appending it to a predefined name.
Useful when you want to run a single instance and don't want to have the random numbers in the instance name.
> This also works through `kgsm.sh` Ex: `kgsm.sh --install factorio --id factorio`

Non `--id` generation hasn't been changed

**Bug fixes**
- Fixed `modules/instances.sh` now properly checks for duplicates when generating instance IDs.

## 1.2.7

Added new default blueprint for [Don't Starve Together](https://store.steampowered.com/app/322330/Dont_Starve_Together/)

**Bug fixes**
- Fixed return and error checking conditions in factorio.overrides.sh

## 1.2.6
Added default blueprint for [Necesse Dedicated Server](https://store.steampowered.com/app/1169040/Necesse/)

## 1.2.5

Added possibility to use `kgsm.sh` from the `$PATH`.


Example:
Create symlink
```sh
sudo ln -s /path/to/kgsm.sh /usr/local/bin/kgsm
```

Call `kgsm` from anywhere:
```sh
kgsm --version
```

## 1.2.4
Added new `[-f | --follow]` argument when fetching logs to read in real-time.
Usage:
```sh
./kgsm.sh --instance <instance> --logs [-f | --follow]
```

**Bug fixes**
- Fixed bug in instances.sh modules when fetching instance logs.

## 1.2.3

**Bug fixes**
- Fixed `modules/deploy.sh` bug that expected the instance's install directory to be empty. That's no longer the case since version `1.2.0`.

## 1.2.1

**Bug fixes**
- Fixed bug in `modules/backup.sh` restore it didn't read the version number.

## 1.2.0

- Added new `config.default.ini` option COMPRESS_BACKUPS that if enabled will use tar to reduce the size of the backups. This option is disabled by default and it has to be manually enabled in your `config.ini` file.

**Bug fixes**
- Fixed issue with exit codes in various modules and kgsm.sh.

## 1.1.1

**Bug fixes**

- Fixed Factorio override not using the `--version` passed to it when downloading, defaulting to latest.

## 1.1.0

**Breaking change**: Moved `--uninstall <instance>` arg to top level instead of having it nested.
Previous: `./kgsm.sh --instance <instance> --uninstall`
New: `./kgsm.sh --uninstall <instance>`

Added feature: ability to add/remove systemd and ufw integration from already created instances.
From the interactive mode menu, select the `Modify` option, then follow the prompts.
Named arguments:

```sh
./kgsm.sh --instance <instance> --modify [--add | --remove] [systemd | ufw]
```

Both the interactive mode `Help` option and `./kgsm.sh --help` will display these new options.

**Full Changelog**: https://github.com/TheKrystalShip/KGSM/compare/1.0.4...1.1.0

## 1.0.4

**Bug fixes**

- Fixed `modules/update.sh` not taking into account the instance lifecycle manager when stopping/starting an instance.

## 1.0.3

- Added new module, blueprint, instance, template common loading functions.
- Changed internal module vars naming convention to lowercase.

**Bug fixes**

- Fixed wrong argument bug when restoring backup using interactive mode.
- Fixed `modules/update.sh` not asking for root password when issuing systemctl commands.
- Fixed some inconsistencies between `--help` functions on different modules.

- Known issue:
  - `modules/update.sh` doesn't take into account the INSTANCE_LIFECYCLE_MANAGER and defaults to using systemctl to manage instances

## 1.0.2

- Changed `modules/instances.sh --print-info` to `modules/instances.sh --info`.
- Added shorthand `kgsm.sh [-i, --instance]` argument option to match the modules.
- Added `kgsm.sh --instance <instance> --info` argument to print out instance information.

**Bug fixes** 

- Fixed systemd file permission and ownership.

## 1.0.1

**Bug fixes**

- Fixed UFW rule formatting in various blueprints to a more explicit definition
- Fixed UFW rule file permissions bug where the file didn't belong to root.
- Fixed port definitions across blueprints to correctly reflect the defaults recommended by official documentation.

## 1.0.0

Initial Release
