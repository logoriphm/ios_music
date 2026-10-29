#!/bin/bash
# Builds the app and writes two native screenshots and a recording using the iOS Simulator.
set -euo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
cd "$project_dir"
tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/fieldtone.XXXXXXXX")"
media_dir="$project_dir/Media/Simulator"
recorder_pid=''
test_pid=''
handshake_dir=''
cleanup() {
    if [[ -n "$recorder_pid" ]]; then kill -INT "$recorder_pid" 2>/dev/null || true; fi
    if [[ -n "$test_pid" ]]; then kill "$test_pid" 2>/dev/null || true; fi
    if [[ -n "$handshake_dir" ]]; then
        rm -f "$handshake_dir/fieldtone-ready" "$handshake_dir/fieldtone-go" "$handshake_dir/fieldtone-done"
    fi
    rm -rf "$tmpdir"
}
trap cleanup EXIT

device_id() {
    xcrun simctl list devices available --json | python3 -c '
import json, sys
devices = json.load(sys.stdin)["devices"]
def version(runtime):
    return tuple(map(int, runtime.split(".iOS-")[-1].split("-")))
for runtime in sorted((r for r in devices if ".iOS-" in r), key=version, reverse=True):
    for device in devices[runtime]:
        if device["name"] == sys.argv[1]:
            print(device["udid"])
            sys.exit(0)
sys.exit("Создайте в Xcode симулятор " + sys.argv[1] + " или передайте его UDID скрипту.")
' "$1"
}
se_id="${1:-$(device_id 'iPhone SE (3rd generation)')}"
max_id="${2:-$(device_id 'iPhone 16 Pro Max')}"
mkdir -p "$tmpdir/captures"
base=(-project Fieldtone.xcodeproj -scheme Fieldtone -configuration Debug -derivedDataPath "$tmpdir/build")
app_id='edu.fieldtone.player'
runner_id='edu.fieldtone.player.uitests.xctrunner'
xcodebuild "${base[@]}" -destination "platform=iOS Simulator,id=$max_id" build-for-testing

screenshot() {
    local device="$1" name="$2"
    xcrun simctl bootstatus "$device" -b
    xcrun simctl status_bar "$device" override --time "9:41"
    xcrun simctl install "$device" "$tmpdir/build/Build/Products/Debug-iphonesimulator/Fieldtone.app"
    xcrun simctl launch --terminate-running-process "$device" "$app_id"
    sleep 2
    xcrun simctl io "$device" screenshot "$tmpdir/captures/$name.png"
}
screenshot "$se_id" iphone-se
screenshot "$max_id" iphone-16-pro-max

# Remove stale handshake files before the runner starts on an existing simulator.
if container="$(xcrun simctl get_app_container "$max_id" "$runner_id" data 2>/dev/null)"; then
    rm -f "$container/tmp/fieldtone-ready" "$container/tmp/fieldtone-go" "$container/tmp/fieldtone-done"
fi

# The TEST_RUNNER_ prefix passes the variable through xcodebuild to the XCTest process.
TEST_RUNNER_FIELDTONE_CAPTURE=1 xcodebuild "${base[@]}" -destination "platform=iOS Simulator,id=$max_id" \
    -parallel-testing-enabled NO -only-testing:FieldtoneUITests/PlayerUITests/testRecordDemo \
    test-without-building > "$tmpdir/test.log" 2>&1 &
test_pid=$!
for ((i=0; i<360; i++)); do
    container="$(xcrun simctl get_app_container "$max_id" "$runner_id" data 2>/dev/null || true)"
    if [[ -n "$container" && -f "$container/tmp/fieldtone-ready" ]]; then
        handshake_dir="$container/tmp"
        break
    fi
    if ! kill -0 "$test_pid" 2>/dev/null; then break; fi
    sleep 0.5
done
if [[ -z "$handshake_dir" ]]; then
    cat "$tmpdir/test.log" >&2
    echo "XCTest не сообщил о готовности к записи." >&2
    exit 1
fi

xcrun simctl io "$max_id" recordVideo --codec=h264 "$tmpdir/captures/demo.mp4" > "$tmpdir/record.log" 2>&1 &
recorder_pid=$!
sleep 0.5
kill -0 "$recorder_pid"
touch "$handshake_dir/fieldtone-go"
for ((i=0; i<135; i++)); do
    if [[ -f "$handshake_dir/fieldtone-done" ]]; then break; fi
    if ! kill -0 "$test_pid" 2>/dev/null; then break; fi
    sleep 0.25
done
kill -INT "$recorder_pid"
wait "$recorder_pid" || [[ -s "$tmpdir/captures/demo.mp4" ]]
recorder_pid=''
if ! wait "$test_pid"; then
    cat "$tmpdir/test.log" >&2
    exit 1
fi
test_pid=''
[[ -f "$handshake_dir/fieldtone-done" && -s "$tmpdir/captures/demo.mp4" ]]
mkdir -p "$media_dir"
cp "$tmpdir/captures/"* "$media_dir/"
python3 - <<'PY'
from pathlib import Path
p = Path("README.md")
text = p.read_text().replace("Media/Preview/", "Media/Simulator/")
text = text.replace("В архиве показаны превью по разметке storyboard. PNG и ролик отрисованы вне iOS Simulator.",
                    "Снимки и запись ниже получены в iOS Simulator скриптом capture.sh.")
p.write_text(text)
PY
echo "Готово. Снимки и видео находятся в Media/Simulator, ссылки в README обновлены."
