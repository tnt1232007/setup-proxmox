#!/bin/bash
# bash template.sh

# Define VM configurations (ID, Name, Disk Size, Cores, Memory, MAC, IP)
# vm-system: adguard-home adguard-home-sync cloudflared dozzle mariadb n8n ntfy portainer postgres redis seaweed-fs tailscale traefik vault-warden wud
# vm-home: docker-proxy home-assistant mosquitto node-red own-tracks traefik-proxy
# vm-media: audio-book-shelf docker-proxy javinizer jdownloader jellyfin kavita kometa komf metube photoprism plex-auto-languages suwayomi traefik-proxy
# vm-misc: browserless docker-proxy excalidraw firefly flaresolverr fresh-rss hemmelig homepage hoppscotch ics-proxy it-tools kutt lazytainer linkding open-gist open-webui pairdrop paperless-ngx photo-pea rallly reactive-resume reubah slink speedtest-tracker stirling-pdf surmai traefik-proxy wallos
# 08 GB RAM = 8192
# 12 GB RAM = 12288
# 16 GB RAM = 16384
# 20 GB RAM = 20480
declare -A VM_CONFIGS=(
    [401]="vm-system 120G 8 16384 bc:24:11:01:54:6e 192.168.1.81"
    [402]="vm-home 120G 8 8192 bc:24:11:75:15:70 192.168.1.82"
    [403]="vm-media 120G 8 20480 bc:24:11:9e:2b:07 192.168.1.83"
    [404]="vm-misc 120G 8 12288 bc:24:11:d3:bc:6c 192.168.1.84"
)

# Create VMs
VM_TEMPLATE_ID="400"
for VM_ID in "${!VM_CONFIGS[@]}"; do
    IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

    echo "🚀 Creating VM: $NAME (ID: $VM_ID)"

    # Clone the base VM
    qm clone $VM_TEMPLATE_ID $VM_ID --name "$NAME" --full true

    # Resize disk
    qm resize $VM_ID scsi0 "$DISK"

    # Set CPU and Memory
    qm set $VM_ID --cores "$CORES"
    qm set $VM_ID --memory "$MEMORY"

    # Configure Network
    qm set $VM_ID --net0 virtio,bridge=vmbr0,macaddr="$MAC"
    qm set $VM_ID --ipconfig0 ip="$IP/24",gw=192.168.1.1
    qm set $VM_ID --onboot 1

    echo "✅ $NAME ($VM_ID) created successfully!"
done

# Push SSH Key to VMs
for VM_ID in "${!VM_CONFIGS[@]}"; do
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
done

: <<'EOF'
for VM_ID in "${!VM_CONFIGS[@]}"; do
    IFS=" " read -r NAME DISK CORES MEMORY MAC IP <<< "${VM_CONFIGS[$VM_ID]}"

    echo "🚀 Stopping VM: $NAME ($VM_ID)"
    qm stop $VM_ID
    qm destroy $VM_ID
    echo "✅ $NAME ($VM_ID) destroyed successfully!"
done
EOF