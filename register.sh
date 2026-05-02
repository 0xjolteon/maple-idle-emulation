#!/bin/bash
set -e

# Get device ID
adb -s 127.0.0.1:5555 root
deviceid=$(adb -s 127.0.0.1:5555 shell 'sqlite3 /data/user/$(cmd activity get-current-user)/*/*/gservices.db "select * from main where name = \"android_id\";"' 2>&1)
sqlite_status=$?
adb -s 127.0.0.1:5555 unroot
deviceid=$(echo "$deviceid" | cut -d'|' -f2)
if [ $sqlite_status -ne 0 ]; then
    echo "Error getting device ID: $deviceid"
    exit 1
fi

echo "Your device ID is: $deviceid"
echo "Go to https://google.com/android/uncertified and register this ID."
echo "Note: Verification may take up to 24 hours to complete."
echo ""
read -p "Have you submitted your device ID at google.com/android/uncertified? (y/n): " confirmed

if [ "$confirmed" != "y" ]; then
    echo "Please complete registration first, then rerun this script."
    echo "Once confirmed, rerun this script to force Google Play to recheck certification."
    exit 0
fi

echo "Clearing Google Play data to force certification recheck..."
adb -s 127.0.0.1:5555 shell pm clear com.android.vending || { echo "Error clearing Play Store data"; exit 1; }
adb -s 127.0.0.1:5555 shell pm clear com.google.android.gms || { echo "Error clearing Play Services data"; exit 1; }

echo "Done! If the Play Store still shows Pending, wait a little longer and rerun this script to recheck."
