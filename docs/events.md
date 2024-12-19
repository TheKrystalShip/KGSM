# KGSM Socket Events

KGSM broadcasts key events in JSON format through a Unix Domain Socket. This allows external tools, like KGSM-Bot, to react to server lifecycle changes and other actions. This document outlines all the available events and their structure.

---

## Event Structure

Each event is sent as a JSON object with the following format:

```json
{
    "EventType": "<event_name>",
    "Data": { <event_specific_data> }
}
```

- **EventType**: The name of the event.
- **Data**: An object containing event-specific information.

### Example

```json
{
    "EventType": "instance_started",
    "Data": {
        "Instance": "my_server_instance",
        "Timestamp": "2024-12-19T15:30:00Z"
    }
}
```

---

## List of Events

### Instance Creation

- **`instance_created`**: Triggered when an instance creation process starts.
- **`instance_directories_created`**: Triggered after directories are created.
- **`instance_files_created`**: Triggered after files are generated.
- **`instance_download_started`**: Triggered when the download process begins.
- **`instance_download_finished`**: Triggered when the download process ends.
- **`instance_downloaded`**: Triggered after all files are downloaded.
- **`instance_deploy_started`**: Triggered when the deployment process begins.
- **`instance_deploy_finished`**: Triggered when the deployment process ends.
- **`instance_deployed`**: Triggered after all files are deployed.
- **`instance_update_started`**: Triggered when an update process begins.
- **`instance_update_finished`**: Triggered when an update process ends.
- **`instance_updated`**: Triggered after the instance is updated.
- **`instance_version_updated`**: Triggered after the instance version is updated.

### Instance Installation

- **`instance_installation_started`**: Triggered when the installation process begins.
- **`instance_installation_finished`**: Triggered when the installation process ends.
- **`instance_installed`**: Triggered after the instance is fully installed.

### Lifecycle Events

- **`instance_started`**: Triggered when an instance starts.
- **`instance_stopped`**: Triggered when an instance stops.
- **`instance_backup_created`**: Triggered after a backup is created.
- **`instance_backup_restored`**: Triggered after a backup is restored.

### Instance Removal

- **`instance_files_removed`**: Triggered after instance files are removed.
- **`instance_directories_removed`**: Triggered after directories are removed.
- **`instance_removed`**: Triggered when the instance is removed.

### Uninstallation

- **`instance_uninstall_started`**: Triggered when the uninstallation process begins.
- **`instance_uninstall_finished`**: Triggered when the uninstallation process ends.
- **`instance_uninstalled`**: Triggered after the instance is fully uninstalled.

---

## Emitting Events

Events are emitted through a function called `__emit_event`. Below is a breakdown of how this function works:

### Function Syntax

```bash
__emit_event <event_name> <event_data>
```

- **`<event_name>`**: The name of the event to emit.
- **`<event_data>`**: JSON-formatted string containing additional data for the event.

### Example

```bash
__emit_event "instance_started" '{"Instance": "my_server_instance", "Timestamp": "2024-12-19T15:30:00Z"}'
```

### Socket File

The events are written to the socket file located at:

```bash
$KGSM_ROOT/$EVENTS_SOCKET_FILE
```

Ensure the socket file exists before emitting events. If the socket file is missing, events will not be broadcast.

---

## Integration Notes

- **Reliability**: Ensure your listener application can reconnect to the socket if it is recreated.
- **Filtering**: Use the `EventType` field to filter and handle specific events.
- **Error Handling**: Log or handle scenarios where the socket file is unavailable.

