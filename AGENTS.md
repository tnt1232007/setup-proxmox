# AGENTS.md — setup-proxmox

## Project Overview

Bash scripts to provision VMs and LXC containers on Proxmox VE.
Shared library: `build.func` (sourced by all scripts, auto-fetched from GitHub if missing).
Owner: Nhan Ngo (`tnt1232007@gmail.com`). Repo: `tnt1232007/setup-proxmox`.

---

## Repository Layout

```
setup-proxmox/
├── build.func            # shared library — parse_input, configure_*, print_help, etc.
├── vm-linux.sh           # create Alpine/Debian/Ubuntu VM
├── vm-linux-batch.sh     # interactive batch create/configure/delete Linux VMs
├── vm-windows.sh         # create Windows 10/11 VM
├── vm-macos.sh           # create macOS VM (Sequoia default)
├── vm-popos.sh           # create Pop!_OS VM
├── lxc.sh                # create Alpine/Debian/Ubuntu LXC container
└── lxc-kasm.sh           # create Kasm Workspaces LXC container
```

---

## Script Invocation

All scripts run directly (not sourced). Can be piped from GitHub:

```bash
bash vm-linux.sh <ID> --os <alpine|debian|ubuntu> [OPTIONS]
bash vm-windows.sh <ID> [OPTIONS]
bash vm-macos.sh <ID> [OPTIONS]
bash lxc.sh <ID> --os <alpine|debian|ubuntu> [OPTIONS]

# Remote (wget)
wget -qO- https://raw.githubusercontent.com/tnt1232007/setup-proxmox/refs/heads/main/vm-linux.sh | bash -s -- <ID> --os ubuntu
```

---

## Common Options (all scripts)

| Flag | Default | Notes |
|------|---------|-------|
| `<ID>` | required | Proxmox VM/LXC ID (integer) |
| `--os` | required (linux/lxc) | `alpine` / `debian` / `ubuntu` |
| `--ver` | latest | OS version string |
| `--core` | 8 (VM) / 4 (LXC) | CPU cores |
| `--ram` | 8192 (VM) / 4096 (LXC) | RAM in MB |
| `--disk` | 80G (VM) / 40G (LXC) | Disk size |
| `--name` | auto-generated | Explicit VM/LXC name |
| `--noop` | off | Dry-run, no changes made |

---

## Storage & Host Config (`build.func`)

| Variable | Value |
|----------|-------|
| `HOST_VM_STORAGE` | `local-lvm` |
| `HOST_ISO_STORAGE` | `nas-syno` |
| `MOUNT_STORAGE` | `/mnt/pve/nas-syno` |

SSH keys: fetched from GitHub (`tnt1232007`) and injected via cloud-init or container config.
Random passwords generated per VM for root access.

---

## `build.func` Key Functions

| Function | Purpose |
|----------|---------|
| `print_help` | Print usage; exits if no args |
| `parse_input` | Parse CLI flags into variables |
| `configure_host_storage` | Set storage paths |
| `configure_vm_settings` | Set cores/RAM/disk |
| `configure_os_settings` | Resolve OS image/distro/version |
| `configure_network_settings` | Set network interface |
| `configure_random_password` | Generate root password |
| `review_configurations` | Print resolved config |
| `check_noop` | Exit early if `--noop` |
| `configure_uptime_cronjob` | BetterStack heartbeat cron |

---

## VM vs LXC Defaults

| Type | Cores | RAM | Disk |
|------|-------|-----|------|
| VM | 8 | 8192 MB | 80 GB |
| LXC | 4 | 4096 MB | 40 GB |

---

## Agent Notes

- `build.func` must be present locally or auto-fetched via `wget` from main branch.
- `--noop` flag is safe for all scripts — use to validate configs before real run.
- `vm-linux-batch.sh` is interactive (menu-driven) — not suitable for non-interactive piping.
- macOS VMs require special Proxmox patches; `vm-macos.sh` handles OSX-KVM setup.
- LXC containers use unprivileged mode by default.
- `configure_uptime_cronjob` hardcodes a BetterStack heartbeat URL — update if reusing.

---

## Validation Workflow

- Syntax check edited scripts: `bash -n <script>.sh` and `bash -n build.func`
- Behavior check before destructive operations: run target script with `--noop`
- Prefer local `build.func` during development for deterministic runs; remote auto-fetch can change behavior over time.

## Known Drift To Watch

- Docs often show `--disk 80G/40G`, while parser behavior may expect numeric-only input in `build.func`; verify current parser before editing docs or examples.
- Some docs/reference text may mention `lxc-pbs.sh`; active generic LXC entrypoint in this repo is `lxc.sh`.

## Non-Interactive Caveat

- Some flows prompt on TTY (for example overwrite confirmations); automation should assume prompts unless execution exits early via `--noop`.
