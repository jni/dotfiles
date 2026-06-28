#!/usr/bin/env sh
# Compact power menu via wofi, anchored to the bottom-right next to the Waybar
# ⏻ button. Entries are ordered so the most-used actions (Logout/Lock) sit at
# the BOTTOM of the list, closest to the button you just clicked.
#
# Invoked by $mod+Escape (sway/config) and the custom/power Waybar module
# (waybar/config). Lock goes through `loginctl lock-session`, which swayidle's
# `lock` handler turns into the themed $lock (see sway/config).
#
# --cache-file /dev/null keeps wofi from reordering entries by usage frequency,
# so the deliberate ordering below is preserved.

chosen=$(printf '%s\n' \
    Shutdown \
    Reboot \
    Hibernate \
    Suspend \
    Logout \
    Lock \
  | wofi --dmenu --prompt Power \
         --location bottom_right --width 200 --lines 7 \
         --cache-file /dev/null)

case "$chosen" in
    Lock)      loginctl lock-session ;;
    Logout)    swaymsg exit ;;
    Suspend)   systemctl suspend ;;
    Hibernate) systemctl hibernate ;;
    Reboot)    systemctl reboot ;;
    Shutdown)  systemctl poweroff ;;
esac
