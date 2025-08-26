# 08 GB RAM = 8192, 12 GB RAM = 12288, 16 GB RAM = 16384, 20 GB RAM = 20480
declare -A VM_CONFIGS=(
    [401]="vm-system 120G 8 16384 bc:24:11:01:54:6e 192.168.1.81"
    [402]="vm-home 80G 8 12288 bc:24:11:75:15:70 192.168.1.82"
    [403]="vm-media 80G 8 20480 bc:24:11:9e:2b:07 192.168.1.83"
    [404]="vm-misc 40G 8 12288 bc:24:11:d3:bc:6c 192.168.1.84"
)
VM_TEMPLATE_ID="400"

create() {
    echo "🚀 Creating VMs from template ID: $VM_TEMPLATE_ID"
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort -n); do
        IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

        echo "🚀 Creating VM: $NAME (ID: $VM_ID)"
        qm clone $VM_TEMPLATE_ID $VM_ID --name "$NAME" --full true
        qm resize $VM_ID scsi0 "$DISK"

        qm set $VM_ID --cores "$CORES"
        qm set $VM_ID --memory "$MEMORY"
        qm set $VM_ID --net0 virtio,bridge=vmbr0,macaddr="$MAC"
        qm set $VM_ID --ipconfig0 ip="$IP/24",gw=192.168.1.1
        qm set $VM_ID --onboot 1

        echo "✅ $NAME ($VM_ID) created successfully!"
    done
}

configure() {
    echo "🚀 Configuring VMs..."
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort -n); do
        IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

        TIMEOUT=30
        INTERVAL=1
        ELAPSED=0
        echo "🚀 Starting $NAME ($VM_ID)..."
        qm start $VM_ID
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            VM_IP=$(qm guest exec $VM_ID -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n 1)

            if [[ -n "$VM_IP" ]]; then
                echo "✅ $NAME ($VM_ID) ready, IP: $VM_IP"
                break
            fi

            sleep $((RANDOM % 2 + 1))  # Sleep for 1-2 seconds
            ((ELAPSED+=INTERVAL))
        done

        if [[ -z "$VM_IP" ]]; then
            echo "❌ Timed out waiting for $NAME ($VM_ID)."
            exit 1
        fi

        echo "🚀 Pushing SSH Key to $NAME ($VM_ID)"
        ssh-keyscan -H "$VM_IP" >> ~/.ssh/known_hosts
        scp ~/.ssh/id_ed25519 root@$VM_IP:~/.ssh/id_ed25519
        scp ~/.ssh/id_ed25519.pub root@$VM_IP:~/.ssh/id_ed25519.pub
        echo "✅ SSH Key pushed to $NAME ($VM_ID) successfully!"

        # For vm-home, change generic-cloud to generic for usb-ip drivers
        if [[ "$NAME" == "vm-home" ]]; then
            echo "🚀 Configuring vm-home..."
            apt install linux-image-amd64
            update-grub
            grep menuentry /boot/grub/grub.cfg
            grub-set-default 'Debian GNU/Linux, with Linux 6.1.0-32-amd64'
            grub-editenv list
            reboot
            uname -r
        fi
    done
}

delete() {
    echo "🚀 Deleting all VMs..."
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort -n); do
        IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

        echo "🚀 Stopping VM: $NAME ($VM_ID)"
        qm stop $VM_ID
        qm destroy $VM_ID
        echo "✅ $NAME ($VM_ID) destroyed successfully!"
    done
}

run_script() {
    local script_cmd="${1}"
    echo "🚀 Running script in all VMs..."
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort -n); do
        IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

        echo "🚀 Running script in $NAME ($VM_ID)"
        qm guest exec $VM_ID -- bash -c "$script_cmd"
        echo "✅ Script executed in $NAME ($VM_ID) successfully!"
    done
}

vm_list() {
    local -n FSINFO_CACHE_REF=$1
    local RED=$'\033[0;31m'
    local NC=$'\033[0m'
    local -A LIVE_STATUS
    local -A LIVE_MEM
    local -A LIVE_DISK
    local -A LIVE_NAME

    while read -r line; do
        [[ $line =~ ^[[:space:]]*VMID ]] && continue  # skip header
        [[ $line =~ ^[[:space:]]*$ ]] && continue
        read -r VMID NAME STATUS MEM DISK PID <<< $(echo $line | awk '{print $1, $2, $3, $4, $5, $6}')
        LIVE_STATUS[$VMID]="$STATUS"
        LIVE_MEM[$VMID]="$MEM"
        LIVE_DISK[$VMID]="$DISK"
        LIVE_NAME[$VMID]="$NAME"
    done < <(qm list)

    printf "%-6s %-15s %-10s %-10s %-10s %-10s %-10s %-18s %-15s\n" "VMID" "Name" "Status" "Memory" "Disk(GB)" "Used(GB)" "Free(%)" "MAC" "IP"
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort); do
        IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"
        LIVE_STATUS_VAL="${LIVE_STATUS[$VM_ID]:-N/A}"
        LIVE_MEM_VAL="${LIVE_MEM[$VM_ID]:-N/A}"
        LIVE_DISK_VAL="${LIVE_DISK[$VM_ID]:-N/A}"
        CONFIG_DISK_FLOAT=$(printf "%.2f" "${DISK//G/}")
        LIVE_DISK_FLOAT=$(printf "%.2f" "$LIVE_DISK_VAL")
        OUT_DISK="$LIVE_DISK_VAL"
        if [[ "$LIVE_DISK_VAL" != "N/A" && "$LIVE_DISK_FLOAT" != "$CONFIG_DISK_FLOAT" ]]; then
            OUT_DISK="${RED}$LIVE_DISK_VAL${NC}"
        fi
        OUT_MEM="$LIVE_MEM_VAL"
        if [[ "$LIVE_MEM_VAL" != "N/A" && "$LIVE_MEM_VAL" != "$MEMORY" ]]; then
            OUT_MEM="${RED}$LIVE_MEM_VAL${NC}"
        fi
        local plain_disk=$(echo -e "$OUT_DISK" | sed 's/\x1B\[[0-9;]*[a-zA-Z]//g')
        local len_disk=${#plain_disk}
        local pad_disk=$((10 - len_disk))

        FSINFO="${FSINFO_CACHE_REF[$VM_ID]}"
        USED_GB="N/A"
        FREE_PCT="N/A"
        if [[ -n "$FSINFO" ]]; then
            TOTAL_BYTES=$(echo "$FSINFO" | jq -r '.[] | select(.mountpoint == "/") | ."total-bytes"')
            USED_BYTES=$(echo "$FSINFO" | jq -r '.[] | select(.mountpoint == "/") | ."used-bytes"')
            if [[ -n "$TOTAL_BYTES" && -n "$USED_BYTES" && "$TOTAL_BYTES" -gt 0 ]]; then
                USED_GB=$(awk "BEGIN {printf \"%.2f\", $USED_BYTES/1024/1024/1024}")
                FREE_PCT=$(awk "BEGIN {printf \"%.1f\", 100 - 100*$USED_BYTES/$TOTAL_BYTES}")
            fi
        fi

        printf "%-6s %-15s %-10s %-10s %s%*s %-10s %-10s %-18s %-15s\n" \
            "$VM_ID" "$NAME" "$LIVE_STATUS_VAL" "$OUT_MEM" "$OUT_DISK" "$pad_disk" "" "$USED_GB" "$FREE_PCT" "$MAC" "$IP"
    done
}

main_menu() {
    declare -A FSINFO_CACHE
    while true; do
        # Cache FSINFO for all VMs
        for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort); do
            FSINFO_CACHE[$VM_ID]="$(qm agent "$VM_ID" get-fsinfo 2>/dev/null)"
        done
        echo "======= Proxmox VM Batch Executor ========"
        echo "🚀 VM List:"
        vm_list FSINFO_CACHE
        echo "=========================================="
        echo "🤖 Choose an action:"
        echo "1) 🆕 Create VMs      - Clone and set up all VMs from template."
        echo "2) 🛠️ Configure VMs   - Setup SSH key and configure special VMs."
        echo "3) 🗑️ Delete VMs      - Stop and destroy all VMs."
        echo "4) 📝 Run Script      - Run a custom bash command in all VMs."
        echo "5) 🚪 Exit            - Quit this menu."
        echo "==========================================="
        read -rp "🤔 Enter your choice [1-5]: " choice </dev/tty
        case $choice in
            1)
                create
                ;;
            2)
                configure
                ;;
            3)
                delete
                ;;
            4)
                run_script_menu
                ;;
            5)
                echo "👋 Exiting. Bye!"
                break
                ;;
            *)
                echo "❌ Invalid choice. Please select 1-5."
                ;;
        esac
        if [[ "$choice" != "4" ]]; then
            echo "🔄 Press Enter to return to menu..."
            read -r </dev/tty
        fi
    done
}

run_script_menu() {
    while true; do
        echo "========================================="
        echo "🤖 Choose a script:"
        echo "1) linux-01.sh                - Docker & Git setup"
        echo "2) linux-02-cifs-mount.sh     - Mount CIFS network drives"
        echo "3) linux-03-bash-aliases.sh   - Docker aliases/functions"
        echo "4) linux-04-kernel-changed.sh - Changed kernel"
        echo "5) 📝 Custom script           - Enter your own bash command"
        echo "6) 🚪 Exit to main menu"
        echo "========================================="
        read -rp "🤔 Choose a script to run [1-6]: " script_choice </dev/tty
        case $script_choice in
            1)
                run_script "curl -fsSL https://url.trinitro.io/linux-setup | bash"
                ;;
            2)
                run_script "curl -fsSL https://url.trinitro.io/linux-cifs | bash"
                ;;
            3)
                run_script "curl -fsSL https://url.trinitro.io/linux-alias | bash"
                ;;
            4)
                run_script "curl -fsSL https://url.trinitro.io/linux-kernel | bash"
                ;;
            5)
                read -rp "📝 Enter your custom bash command: " user_cmd </dev/tty
                run_script "$user_cmd"
                ;;
            6)
                break
                ;;
            *)
                echo "❌ Invalid choice. Please select 1-6."
                ;;
        esac
        echo "🔄 Press Enter to return to script menu..."
        read -r </dev/tty
    done
}

check_disk_size() {
    for VM_ID in $(printf "%s\n" "${!VM_CONFIGS[@]}" | sort -n); do
        echo "Checking disk size for VM $VM_ID..."
        qm agent "$VM_ID" get-fsinfo 2>/dev/null | \
            grep -E '"mountpoint"|"total-bytes"|"used-bytes"' | \
            sed 's/[",]//g' | \
            awk '
                /mountpoint/ {mp=$3}
                /total-bytes/ {tb=$3}
                /used-bytes/ {
                    ub=$3;
                    if (mp != "/boot/efi" && tb > 0) {
                        tgb=tb/1024/1024/1024
                        ugb=ub/1024/1024/1024
                        pct=100*ub/tb
                        printf "%.2f GB / %.2f GB | %.1f%% used\n", ugb, tgb, pct
                    }
                }'
    done
}

main_menu