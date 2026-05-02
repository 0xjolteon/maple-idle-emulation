cd ~/redroid

echo "Starting docker container..."
sudo docker compose up -d

echo "Waiting for redroid to start..."
until adb connect 127.0.0.1:5555 2>&1 | grep -q "connected"; do
    sleep 2
done

echo "Device connected, waiting for boot to complete..."
adb -s 127.0.0.1:5555 wait-for-device shell 'while [[ -z $(getprop sys.boot_completed) ]]; do sleep 2; done'

echo "Starting KISS launcher..."
adb -s 127.0.0.1:5555 shell am start -n fr.neamar.kiss/.MainActivity

echo "Device ready!"
