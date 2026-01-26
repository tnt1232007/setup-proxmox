configure_uptime_cronjob() {
    echo "🔧 Configuring uptime cronjob..."
    URL="https://uptime.betterstack.com/api/v1/heartbeat/iWcryV4fBnL7a2oo2LodoSVT"
    CRON_CMD="*/5 * * * * root curl -fsS --retry 3 $URL > /dev/null 2>&1"
    CRON_JOB_FILE="/etc/cron.d/betterstack-uptime"

    echo "$CRON_CMD" > "$CRON_JOB_FILE"
    chmod 644 "$CRON_JOB_FILE"
    systemctl restart cron
    systemctl status cron || true
}