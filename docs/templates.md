# Templates in KGSM

Templates in KGSM are standardized files that provide consistent structure for various aspects of game server management. They act as blueprints that define what information KGSM needs to parse, generate, and manage game server configurations effectively.

## Purpose and Function

Templates serve to:
- Standardize configuration formats across different game servers
- Enable reliable parsing and extraction of user settings
- Provide a base for generating implementation files
- Support user customization through a consistent interface

KGSM stores template files with a `.tp` extension in the `/templates` directory, and users should never modify these directly. Instead, users create their own configuration files based on these templates in the appropriate directories (`/blueprints`, `/instances`, or `/overrides`).

## Template Types

KGSM utilizes several template types:

### Configuration Templates
- **Blueprint Templates** (`blueprint.tp`): Define game server configurations with fields for server info, Steam integration, executable paths, and runtime parameters
- **Instance Templates** (`instance.tp`): Configure deployed game server instances with identification, blueprint references, and runtime settings

### Management Templates
- **Native Management** (`manage.native.tp`): Generate scripts for managing native processes (start/stop, backups, updates)
- **Container Management** (`manage.container.tp`): Generate scripts for containerized servers (lifecycle, volumes, networking)

### System Integration Templates
- **Service Templates** (`service.tp`): Define systemd service files
- **Socket Templates** (`socket.tp`): Define systemd socket files 
- **Firewall Templates** (`ufw.tp`): Define firewall rules for network access

### Customization Templates
- **Override Templates** (`overrides.tp`): Provide structure for custom function implementations

## Working with Templates

### Structure and Format

Template files follow a consistent structure:
- Header comments with usage instructions
- Configuration parameters with clear explanations
- Optional sections for advanced settings

Most templates use an INI-like format with parameter names and values, making them easy to read and modify:

```ini
# Parameter description
parameter_name=value
```

### Template Variables

Templates may contain variables that KGSM replaces during processing:
- `$instance_name`: The unique identifier for an instance
- `$instance_blueprint_file`: Path to the blueprint file used by an instance
- `$instance_working_dir`: The working directory for an instance

### Usage Guidelines

When working with templates:
1. **Never modify template files** in the `/templates` directory
2. Create new configuration files in their appropriate directories instead
3. Reference the template structure when creating new configurations
4. Advanced users can extend the system with custom templates

## Conclusion

Templates provide the foundation for KGSM's flexibility and standardization, enabling seamless configuration and management of diverse game server types while maintaining a consistent interface.
