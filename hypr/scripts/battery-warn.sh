BAT="BAT0"

CAPACITY=$(cat /sys/class/power_supply/$BAT/capacity)
STATUS=$(cat /sys/class/power_supply/$BAT/status)

notify() {
    notify-send -u "$1" "$2" "$3"
}

if [ "$STATUS" = "Discharging" ]; then
    if [ "$CAPACITY" -le 20 ] && [ "$CAPACITY" -gt 10 ]; then
        notify normal "🔋 Battery $CAPACITY%" "Low charge"
    elif [ "$CAPACITY" -le 10 ] && [ "$CAPACITY" -gt 5 ]; then
        notify critical "🔋 Battery $CAPACITY%" "Low charge"
    elif [ "$CAPACITY" -le 5 ]; then
        notify critical "⚠️ Battery $CAPACITY%" "Critically low!"
    fi
fi

