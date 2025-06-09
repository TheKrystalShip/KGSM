# 📡 KGSM Event System

KGSM features a robust event broadcasting system that operates through Unix Domain Sockets. This system allows external applications (like [KGSM-Bot](https://github.com/TheKrystalShip/KGSM-Bot)) to monitor and respond to various game server lifecycle events in real-time. The event system provides a clean, decoupled mechanism for extending KGSM's functionality without modifying its core.

## 🔌 How It Works

Events are JSON-formatted messages broadcast through a Unix Domain Socket when specific actions occur within KGSM, such as starting a server instance, creating a backup, or updating a game server. External applications can listen to these events and react accordingly.

### Prerequisites

To enable and use the event system:

1. Set `enable_event_broadcasting=1` in your KGSM configuration file
2. Install the `socat` utility, which is required for Unix socket communication
3. Ensure external applications have read/write access to the socket file location

## 🔄 Event Structure

Each event is transmitted as a JSON object with the following format:

```json
{
    "EventType": "<event_name>",
    "Data": { 
        "InstanceName": "<instance_name>",
        ...other event-specific data
    }
}
```

- `EventType`: A string identifying the event type (e.g., `instance_started`)
- `Data`: An object containing event-specific information, always including at least the `InstanceName`

### Example Event

```json
{
    "EventType": "instance_started",
    "Data": {
        "InstanceName": "minecraft_survival",
        "Blueprint": "minecraft"
    }
}
```

## 📝 Available Events

KGSM broadcasts events for the full lifecycle of game server instances. Events are categorized based on their purpose:

### 🛠️ Instance Creation Events

| Event Name | Description | Additional Data |
|------------|-------------|----------------|
| `instance_installation_started` | Installation process initiated | Blueprint |
| `instance_created` | Instance creation process initiated | Blueprint |
| `instance_directories_created` | Directory structure created | - |
| `instance_files_created` | Configuration files generated | - |
| `instance_download_started` | Download of server files initiated | - |
| `instance_download_finished` | Download of server files completed | - |
| `instance_downloaded` | All required files downloaded | - |
| `instance_deploy_started` | Deployment of server files initiated | - |
| `instance_deploy_finished` | Deployment of server files completed | - |
| `instance_deployed` | Server files fully deployed | - |
| `instance_installation_finished` | Installation process completed | Blueprint |
| `instance_installed` | Server fully installed and ready | Blueprint |

### 🔄 Update Events

| Event Name | Description | Additional Data |
|------------|-------------|----------------|
| `instance_update_started` | Server update initiated | - |
| `instance_update_finished` | Server update completed | - |
| `instance_version_updated` | Server version changed | OldVersion, NewVersion |
| `instance_updated` | Server fully updated | - |

### 🚀 Lifecycle Events

| Event Name | Description | Additional Data |
|------------|-------------|----------------|
| `instance_started` | Server started | - |
| `instance_stopped` | Server stopped | - |
| `instance_backup_created` | Backup created | Source, Version |
| `instance_backup_restored` | Backup restored | Source, Version |

### 🗑️ Removal Events

| Event Name | Description | Additional Data |
|------------|-------------|----------------|
| `instance_uninstall_started` | Uninstallation process initiated | - |
| `instance_files_removed` | Server files removed | - |
| `instance_directories_removed` | Server directories removed | - |
| `instance_removed` | Instance removed | - |
| `instance_uninstall_finished` | Uninstallation process completed | - |
| `instance_uninstalled` | Server fully uninstalled | - |

## 🛠️ Technical Implementation

### Socket File Location

Events are broadcast to the socket file located at:

```
$KGSM_ROOT/$event_socket_filename
```

By default, this resolves to: `$KGSM_ROOT/kgsm.sock`

### How Events Are Emitted

KGSM uses helper functions prefixed with `__emit_` to broadcast events through the socket. The core function that handles event broadcasting is `__emit_event`:

```bash
__emit_event <event_name> <event_data_json>
```

Each event type has its own specific emission function that constructs the appropriate JSON payload and passes it to `__emit_event`.

## 🧩 Integration Guide

### Listening for Events

To listen for KGSM events in your application, you can use tools like `socat` or implement a Unix Domain Socket listener in your preferred programming language. Here's a simple example with `socat`:

```bash
socat UNIX-LISTEN:/path/to/kgsm.sock,fork -
```

For more reliable integration, you should implement:

1. **Connection handling** - Reconnect if the socket is recreated
2. **Event filtering** - Process only events relevant to your application
3. **Error handling** - Gracefully handle cases where the socket is unavailable

### Sample Client Code (Python)

```python
import socket
import json
import os

SOCKET_PATH = "/path/to/kgsm.sock"

def listen_for_events():
    if os.path.exists(SOCKET_PATH):
        os.unlink(SOCKET_PATH)
    
    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.bind(SOCKET_PATH)
    sock.listen(1)
    
    print(f"Listening on {SOCKET_PATH}")
    
    while True:
        connection, client_address = sock.accept()
        try:
            data = connection.recv(1024)
            if data:
                event = json.loads(data.decode('utf-8'))
                print(f"Received event: {event['EventType']}")
                # Process the event based on its type
                process_event(event)
        finally:
            connection.close()

def process_event(event):
    event_type = event['EventType']
    instance_name = event['Data']['InstanceName']
    
    if event_type == 'instance_started':
        print(f"Server {instance_name} has started!")
    elif event_type == 'instance_stopped':
        print(f"Server {instance_name} has stopped!")
    # Handle other event types as needed
```

## ⚙️ Configuration

To enable the event system, edit your KGSM configuration file:

1. Set `enable_event_broadcasting=1` to enable event broadcasting
2. Optionally customize `event_socket_filename` to change the socket file name (default: `kgsm.sock`)

## 🔍 Debugging

If events aren't being broadcast:

1. Verify `enable_event_broadcasting=1` in your configuration
2. Check that `socat` is installed
3. Ensure the socket file exists and has proper permissions
4. Monitor socket activity with: `socat UNIX-CONNECT:/path/to/kgsm.sock -`

## 💡 Best Practices

1. **Reconnection Logic** - Implement robust reconnection handling in client applications
2. **Selective Handling** - Process only events relevant to your application's functionality
3. **Event Validation** - Always validate event data before processing
4. **Atomic Actions** - Keep event handlers atomic; don't create complex dependencies between them
5. **Logging** - Maintain logs of received events for troubleshooting

---

By leveraging KGSM's event system, you can extend the functionality of your game server management with custom notifications, automated actions, monitoring systems, and more, all without modifying the core KGSM codebase.

