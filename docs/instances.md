# Instances 101

This document explains what instances are, how they work in KGSM, and how to create and manage them.

## What is an instance?

An instance is a complete, functional installation of a game server created from a blueprint using KGSM. Each instance is self-contained and includes everything needed to run and manage the server it represents. You can create multiple instances from a single blueprint, each with its own unique configuration and data.

## Where are instances stored?

Instances are located in the installation directory specified during a blueprint's installation process. This directory contains the actual game server files for each instance. Additionally, KGSM uses the `instances` directory to store **instance configuration files**, which are used internally to track and manage instances.

To list all created instances, run:

```sh
./kgsm.sh --instances
```

For example, the output might look like this:

```
minecraft-server-1
valheim-server-2
csgo-server-3
```

## How to create an instance

Creating an instance involves running the installation process for a selected blueprint. During this process, KGSM:

1. Sets up the game server files in the specified installation directory.
2. Generates an **instance configuration file** in the `instances` directory to track the instance.

The instance configuration file includes metadata about the instance, such as the blueprint it was created from, the installation path, and other relevant details. This file is used by KGSM for management tasks like starting, stopping, and updating the instance.

> [!NOTE]
> The instance configuration file is not required by the game server itself; it is only used internally by KGSM.

## Best practices for instance management

- **Avoid manual modifications:** Do not manually edit the instance configuration files unless you are certain of what you are doing. Incorrect changes can cause KGSM to mismanage the instance.

- **Use unique names:** When creating instances, use meaningful and unique names to differentiate them easily. For example, you might name instances based on the game or the server's purpose (e.g., `minecraft-test`, `csgo-competitive`).

- **Back up your data:** Regularly back up important data for each instance, such as save files and configuration settings, to prevent data loss.

## Advanced: Removing an instance

If you need to remove an instance, it is recommended to use KGSM commands rather than deleting files manually. This ensures that:

1. The game server files are properly cleaned up.
2. The instance configuration file is removed from the `instances` directory.

To remove an instance, use a KGSM command such as:

```sh
./kgsm.sh --uninstall <instance-name>
```

---

By following these guidelines, you can effectively create, manage, and remove instances, ensuring smooth operation of your game servers with KGSM.


