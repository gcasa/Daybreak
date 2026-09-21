#!/bin/sh
# GNUstep/X11 startup smoke test. Run under xvfb-run after building the app.
set -eu
mkdir -p build
./Daybreak.app/Daybreak disks-6085/vp2.0.5.zdisk >build/gui-smoke.log 2>&1 &
app_pid=$!
trap 'kill "$app_pid" 2>/dev/null || true' EXIT HUP INT TERM
sleep 5
kill -0 "$app_pid"
# A disk-named window proves launch-file delivery reached our delegate;
# matching only the application name would also accept an error alert.
xdotool search --name 'Daybreak.*vp2.0.5.zdisk' >build/gui-windows.txt
