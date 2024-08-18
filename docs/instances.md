# Instances 101

This document contains all the documentation about instances.

## What is an instance?

An instance is a complete, working installation of a game server created from
a blueprint through KGSM.

You can create as many instances from a blueprint as you want.

## Where to find instances?

Instances are located at the installation directory that was specified during
the installation process.

Instance configuration files can be found in the `instances` directory.

To see a list of created instances, you can run:

```sh
./kgsm.sh --instances
```

## How to create an instance?

Running the installation process for a blueprint will create a new instance of
that blueprint.

KGSM creates and stores an **instance configuration file** in the `instances`
directory when a new instance is created in order to keep track of
installations and allow for management commands to be ran through KGSM itself.

> [!NOTE]
> The instance configuration file itself is not needed by the
> instance, it's only used internally by KGSM.

> [!WARNING]
> It is not recommended to manually modify an instance configuration
> file unless you absolutely know what you're doing.
