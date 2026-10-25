#!/bin/sh
while :; do
  stdbuf -oL dbus-monitor "interface='org.freedesktop.Notifications',member='Notify'" 2>/dev/null |
  while IFS= read -r line; do
    case "$line" in
      "method call"*"member=Notify")
        sender=$(printf '%s' "$line" | sed -n 's/.*sender=\([^ ]*\).*/\1/p')
        read -r appline
        app=$(printf '%s' "$appline" | sed -n 's/^[[:space:]]*string "\(.*\)"$/\1/p')
        read -r replaceline
        rid=$(printf '%s' "$replaceline" | sed -n 's/^[[:space:]]*uint32 \([0-9]*\)$/\1/p')
        if [ "$rid" = "0" ]; then
          pid=$(busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s "$sender" 2>/dev/null | awk '{print $2}')
          [ -z "$pid" ] && pid=-1
          printf '%s\t%s\n' "$pid" "$app"
        fi
        ;;
    esac
  done
  sleep 1
done
