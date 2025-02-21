# Proxmox Setup Scripts

This repository contains scripts to automate the setup of virtual machines and LXC containers on Proxmox. Each script is designed for a specific operating system.

## Linux - `vm-linux.sh`

This script sets up a Linux (Alpine/Debian/Ubuntu) virtual machine.

### USAGE
```bash
bash vm-linux.sh <ID> [OPTIONS]
```

### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--os <os_name>`: The name of the operating system (required, alpine/debian/ubuntu).
- `--ver <os_version>`: The version of the operating system (optional, default=latest).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--noop`: Perform a noop run without making any changes (optional).

### EXAMPLE
```bash
bash vm-linux.sh 999 --os alpine --ver 3.21 --core 4 --ram 4096 --disk 40G --mac XX:XX:XX:XX:XX --noop
wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/vm-linux.sh | bash -s -- vm-linux.sh 999 --os ubuntu
```

## Windows - `vm-windows.sh`

This script sets up a Windows virtual machine.

### USAGE
```bash
bash vm-windows.sh <ID> [OPTIONS]
```

### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--ver <os_version>`: The version of the operating system (optional, default=11).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--noop`: Perform a noop run without making any changes (optional).

### EXAMPLE
```bash
bash vm-windows.sh 999 --ver 11 --core 4 --ram 4096 --disk 40G --mac XX:XX:XX:XX:XX --noop
wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/vm-windows.sh | bash -s -- vm-windows.sh 999
```

## MacOS - `vm-macos.sh`

This script sets up a macOS virtual machine.

### USAGE
```bash
bash vm-macos.sh <ID> [OPTIONS]
```

### OPTIONS
- `<ID>`: The unique ID of the VM (required).
- `--ver <os_version>`: The version of the operating system (optional, default=15).
- `--core <cores>`: Number of CPU cores for the VM (optional, default=8).
- `--ram <memory>`: Amount of RAM for the VM in MB (optional, default=8192).
- `--disk <size>`: Disk size for the VM (optional, default=80G).
- `--mac <address>`: MAC address for the VM network interface (optional, default=random).
- `--noop`: Perform a noop run without making any changes (optional).

### EXAMPLE
```bash
bash vm-macos.sh 999 --ver 14 --core 4 --ram 4096 --disk 40G --mac XX:XX:XX:XX:XX --noop
wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/vm-macos.sh | bash -s -- vm-macos.sh 999
```

## LXCs - `lxc-pbs.sh` && `lxc-kasm.sh`

These scripts set up LXC containers based on Alpine/Debian/Ubuntu OS.

### USAGE
```bash
bash lxc-pbs.sh <ID> [OPTIONS]
bash lxc-kasm.sh <ID> [OPTIONS]
```

### OPTIONS
- `<ID>`: The unique ID of the LXC container (required).
- `--os <os_name>`: The name of the operating system (required, alpine/debian/ubuntu).
- `--ver <os_version>`: The version of the operating system (optional, default=latest).
- `--core <cores>`: Number of CPU cores for the LXC container (optional, default=4).
- `--ram <memory>`: Amount of RAM for the LXC container in MB (optional, default=4096).
- `--disk <size>`: Disk size for the LXC container (optional, default=40G).
- `--mac <address>`: MAC address for the LXC container network interface (optional, default=random).
- `--noop`: Perform a noop run without making any changes (optional).

### EXAMPLE
```bash
bash lxc-pbs.sh 999 --os debian --ver 12 --core 4 --ram 4096 --disk 40G --mac XX:XX:XX:XX:XX --noop
wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/lxc-kasm.sh | bash -s -- lxc-kasm.sh 999 --os ubuntu
```
