#!/system/bin/sh
# Auto-switch TCP congestion control: BBRv2 ↔ Westwood
LOG_TAG="net-cc-auto"
SLEEP_INTERVAL=15

set_algorithm() {
    ALGO=$1
    IFACE=$2
    if [ "$ALGO" = "bbr2" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=bbr2
        tc qdisc replace dev $IFACE root fq 2>/dev/null
        log -t $LOG_TAG "Switched $IFACE -> BBRv2"
    elif [ "$ALGO" = "westwood" ]; then
        sysctl -w net.ipv4.tcp_congestion_control=westwood
        tc qdisc replace dev $IFACE root fq_codel 2>/dev/null
        log -t $LOG_TAG "Switched $IFACE -> Westwood"
    fi
}

get_interfaces() {
    WIFI_IF=$(ip link | grep -E "wlan|wl" | awk -F: '{print $2}' | tr -d ' ')
    MOBILE_IF=$(ip link | grep -E "rmnet|ccmni|usb" | awk -F: '{print $2}' | tr -d ' ')
}

CURRENT_ALGO=""
while true; do
    get_interfaces
    [ -z "$WIFI_IF" ] && [ -z "$MOBILE_IF" ] && sleep $SLEEP_INTERVAL && continue
    ACTIVE=$(dumpsys connectivity | grep "ActiveNetwork" -A 3)
    if echo "$ACTIVE" | grep -q "WIFI"; then
        if [ "$CURRENT_ALGO" != "bbr2" ]; then
            set_algorithm bbr2 $WIFI_IF
            CURRENT_ALGO="bbr2"
        fi
    elif echo "$ACTIVE" | grep -q "MOBILE"; then
        if [ "$CURRENT_ALGO" != "westwood" ]; then
            set_algorithm westwood $MOBILE_IF
            CURRENT_ALGO="westwood"
        fi
    fi
    sleep $SLEEP_INTERVAL
done
