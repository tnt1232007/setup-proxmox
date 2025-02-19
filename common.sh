DRY_RUN=false
OS_NAME=""
OS_VERSION=""
OS_DISTRO=""
VM_ID=""
VM_CORES=8
VM_MEM=8192
VM_DISK="80G"
VM_MAC=""

error() {
    echo "❌ Error: $1" >&2
    if [[ "$DRY_RUN" == false ]]; then
        exit 1
    fi
}

highlight() {
    echo -e "\033[0;33m$1\033[0m"
}

print_help() {
    SCRIPT_NAME="$1"
    shift
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
            echo "✍️ USAGE: bash $SCRIPT_NAME <ID> [OPTIONS]"
            echo ""
            echo "  Create a new virtual machine in proxmox."
            echo ""
            echo "  <ID>                 (required)"
            echo "      The unique ID of the VM."
            echo ""
            OS_OPTION=""
            if [[ "$SCRIPT_NAME" == "vm-linux.sh" ]]; then
                echo "  --os <os_name>       (required, debian/ubuntu)"
                echo "      The name of the operating system."
                echo ""
                OS_OPTION=" --os debian"
            fi
            echo "  --ver <os_version>   (optional, default=latest)"
            echo "      The version of the operating system."
            echo ""
            echo "  --core <cores>       (optional, default=4)"
            echo "      Number of CPU cores for the VM."
            echo ""
            echo "  --ram <memory>       (optional, default=4096)"
            echo "      Amount of RAM for the VM in MB."
            echo ""
            echo "  --disk <size>        (optional, default=40G)"
            echo "      Disk size for the VM."
            echo ""
            echo "  --mac <address>      (optional, default=random)"
            echo "      MAC address for the VM network interface."
            echo ""
            echo "  --dry                (optional)"
            echo "      Perform a dry run without making any changes."
            echo ""
            echo "✍️ EXAMPLE: bash $SCRIPT_NAME 999$OS_OPTION --ver xx --core 4 --ram 4096 --disk 40G --mac xx:xx:xx:xx:xx:xx --dry"
            echo "✍️ EXAMPLE: wget -qLO - https://gist.trinitro.io/tnt1232007/setup-proxmox/raw/HEAD/$SCRIPT_NAME | bash -s -- 999$OS_OPTION"
            exit 0
        fi
    done
}

parse_input() {
    echo "🔧 Parsing input configurations..."
    if [[ -z "$1" ]]; then
        error "VM_ID is required"
    fi
    VM_ID="$1"
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --os) OS_NAME="$2"; shift 2 ;;
            --ver) OS_VERSION="$2"; shift 2 ;;
            --core) VM_CORES="$2"; shift 2 ;;
            --ram) VM_MEM="$2"; shift 2 ;;
            --disk) VM_DISK="$2"; shift 2 ;;
            --mac) VM_MAC="$2"; shift 2 ;;
            --dry) DRY_RUN=true; shift ;;
            *) echo "❌ Error: Invalid option $1" >&2; exit 1 ;;
        esac
    done
}

check_dry_run() {
    if [[ "$DRY_RUN" == true ]]; then
        echo "✅ Operation cancelled by dry run."
        exit 1
    fi
}

configure_host_storage() {
    echo "🔧 Configuring host storage..."
    HOST_VM_STORAGE="local-lvm"
    HOST_ISO_STORAGE="nas-synology-external"
    MOUNT_STORAGE="/mnt/pve/nas-synology-external"
    if ! pvesm status | grep -q "^$HOST_VM_STORAGE"; then
        error "Storage '$HOST_VM_STORAGE' not found"
    fi
    if ! pvesm status | grep -q "^$HOST_ISO_STORAGE"; then
        error "Storage '$HOST_ISO_STORAGE' not found"
    fi
}

configure_vm_settings() {
    echo "🔧 Configuring VM settings..."
    if [[ -z "$VM_ID" ]]; then
        error "VM_ID is required"
    elif qm status $VM_ID &>/dev/null; then
        error "VM ID $VM_ID already exists"
    fi
}

configure_os_settings() {
    echo "🔧 Configuring OS settings..."
    if [[ "$SCRIPT_NAME" == "vm-linux.sh" && "$OS_NAME" == "debian" ]]; then
        OS_VERSION="${OS_VERSION:-12}"
        case "$OS_VERSION" in
            12) OS_DISTRO="bookworm" ;;
            11) OS_DISTRO="bullseye" ;;
            10) OS_DISTRO="buster" ;;
            *) error "OS_VERSION $OS_NAME $OS_VERSION not supported (12 -> 10)" ;;
        esac
        OS_IMAGE_LINK="https://cloud.debian.org/images/cloud/$OS_DISTRO/latest/debian-$OS_VERSION-genericcloud-amd64.qcow2"
    elif [[ "$SCRIPT_NAME" == "vm-linux.sh" && "$OS_NAME" == "ubuntu" ]]; then
        OS_VERSION="${OS_VERSION:-24.10}"
        case "$OS_VERSION" in
            24.10) OS_DISTRO="oracular" ;;
            24.04) OS_DISTRO="noble" ;;
            23.10) OS_DISTRO="mantic" ;;
            23.04) OS_DISTRO="lunar" ;;
            22.10) OS_DISTRO="kinetic" ;;
            22.04) OS_DISTRO="jammy" ;;
            *)  error "OS_VERSION $OS_NAME $OS_VERSION not supported (24.10 -> 22.04)" ;;
        esac
        OS_IMAGE_LINK="https://cloud-images.ubuntu.com/releases/$OS_DISTRO/release/ubuntu-$OS_VERSION-server-cloudimg-amd64.img"
    elif [[ "$SCRIPT_NAME" == "vm-macos.sh" ]]; then
        OS_NAME="macos"
        OS_VERSION="${OS_VERSION:-15}"
        case "$OS_VERSION" in
            # 15) OS_DISTRO="sequoia" ;; # not availble yet
            14) OS_DISTRO="sonoma" ;;
            13) OS_DISTRO="ventura" ;;
            12) OS_DISTRO="monterey" ;;
            11) OS_DISTRO="big_sur" ;;
            *)  error "OS_VERSION $OS_NAME $OS_VERSION not supported (15 -> 11)" ;;
        esac
        OS_IMAGE_LINK="https://archive.org/download/macOS-X-images/${OS_DISTRO^}%20$OS_VERSION.iso"
    elif [[ "$SCRIPT_NAME" == "vm-windows.sh" ]]; then
        OS_NAME="windows"
        OS_VERSION="${OS_VERSION:-11}"
        # https://archive.org/search?query=creator%3A%22Microsoft%22&sort=-downloads
        case "$OS_VERSION" in
            11) OS_IMAGE_LINK="https://archive.org/download/win-11-english-x-64v-1_20220628/Win11_English_x64v1.iso" ;;
            10) OS_IMAGE_LINK="https://archive.org/download/windows-10-22h2-x64-english/en-us_windows_10_22h2_updated_may_2023_x64_dvd_8ae93bf4.iso" ;;
            8) OS_IMAGE_LINK="https://archive.org/download/win-8.1-english-x-64_20211019/Win8.1_English_x64.iso" ;;
            7) OS_IMAGE_LINK="https://archive.org/download/win-7-pro-32-64-iso/64-bit/GSP1RMCPRXFRER_EN_DVD.ISO" ;;
            VISTA) OS_IMAGE_LINK="https://archive.org/download/win-vista-ultimate-x64/Win%20Vista%20Ultimate%20x64.iso" ;;
            XP) OS_IMAGE_LINK="https://archive.org/download/WinXPProSP3x86/en_windows_xp_professional_with_service_pack_3_x86_cd_vl_x14-73974.iso" ;;
            *)  error "OS_VERSION $OS_NAME $OS_VERSION not supported (11, 10, 8, 7, VISTA, XP)" ;;
        esac
    elif [[ -z "$OS_NAME" ]]; then
        error "OS_NAME(-os) is required"
    else
        error "OS_NAME $OS_NAME not supported"
    fi

    if [[ -v OS_IMAGE_LINK && -n "$OS_IMAGE_LINK" ]] && ! curl --head --silent --fail "$OS_IMAGE_LINK" > /dev/null; then
        error "Invalid OS image link: $OS_IMAGE_LINK"
    fi
}

configure_network_settings() {
    echo "🔧 Configuring network settings..."
    VM_NET="${1:-virtio},bridge=vmbr0"
    if [[ -n "$VM_MAC" ]]; then
        VM_NET="$VM_NET,macaddr=${VM_MAC}"
    fi
}

review_configurations() {
    echo "🔧 Review the following configurations:"
    echo "👉 OS Name: $(highlight "$OS_NAME")"
    echo "👉 OS Version: $(highlight "$OS_VERSION")"
    if [[ "$SCRIPT_NAME" != "vm-windows.sh" ]]; then
        echo "👉 OS Distro: $(highlight "$OS_DISTRO")"
    fi
    echo "👉 VM ID: $(highlight "$VM_ID")"
    echo "👉 Cores: $(highlight "$VM_CORES")"
    echo "👉 Memory: $(highlight "$VM_MEM")"
    echo "👉 Disk: $(highlight "$VM_DISK")"
    echo "👉 Network: $(highlight "$VM_NET")"
    read -p "❓ Do you want to proceed with these settings? (y/n): " confirm
    if [[ "$confirm" != "y" ]]; then
        echo "✅ Operation cancelled by user."
        exit 1
    fi
}

print_success_message() {
    echo "✅ VM $VM_ID created successfully:"
    echo "👉 To start the VM: qm start $VM_ID"
    echo "👉 To convert to template: qm template $VM_ID"
}
