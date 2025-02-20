# Proxmox Setup Scripts

This repository contains scripts to automate the setup of virtual machines on Proxmox. Each script is designed for a specific operating system.

## Scripts

### vm-linux.sh

This script sets up a Linux virtual machine.

#### USAGE
```bash
bash vm-linux.sh <ID> [OPTIONS]
```

#### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--os <os_name>`: The name of the operating system (required, debian/ubuntu).
- `--ver <os_version>`: The version of the operating system (optional, default=latest).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--dry`: Perform a dry run without making any changes (optional).

#### EXAMPLE
```bash
bash vm-linux.sh 999 --os ubuntu --ver 22.04 --core 4 --ram 4096 --disk 40G --mac 52:54:00:12:34:56 --dry
```

### vm-windows.sh

This script sets up a Windows virtual machine.

#### USAGE
```bash
bash vm-windows.sh <ID> [OPTIONS]
```

#### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--ver <os_version>`: The version of the operating system (optional, default=11).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--dry`: Perform a dry run without making any changes (optional).

#### EXAMPLE
```bash
bash vm-windows.sh 999 --ver 10 --core 4 --ram 4096 --disk 40G --mac 52:54:00:12:34:56 --dry
```

### vm-macos.sh

This script sets up a macOS virtual machine.

#### USAGE
```bash
bash vm-macos.sh <ID> [OPTIONS]
```

#### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--ver <os_version>`: The version of the operating system (optional, default=15).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--dry`: Perform a dry run without making any changes (optional).

#### EXAMPLE
```bash
bash vm-macos.sh 999 --ver 14 --core 4 --ram 4096 --disk 40G --mac 52:54:00:12:34:56 --dry
```
