#!/bin/bash
echo "=== KernelSU Complete Diagnostic ==="
echo ""

echo "[1] Find where kernel calls ksud..."
cd ~/kernel_xiaomi_ysl
grep -n "post_fs_data" KernelSU/kernel/ksud.c KernelSU/kernel/kp_hook.c 2>/dev/null | head -20
echo ""

echo "[2] Check for usermode helper calls..."
grep -n "call_usermodehelper\|ksu.*exec" KernelSU/kernel/*.c 2>/dev/null | grep -i ksud
echo ""

echo "[3] Create magisk stub properly..."
adb shell 'su -c "mkdir -p /data/adb"'
adb shell 'su -c "echo \"#!/system/bin/sh\" > /data/adb/magisk"'
adb shell 'su -c "echo \"case \\\$1 in\" >> /data/adb/magisk"'
adb shell 'su -c "echo \"  --path) echo /data/adb ;;\" >> /data/adb/magisk"'
adb shell 'su -c "echo \"  --version) echo 27000 ;;\" >> /data/adb/magisk"'
adb shell 'su -c "echo \"  --version-code) echo 27000 ;;\" >> /data/adb/magisk"'
adb shell 'su -c "echo \"  *) echo KernelSU-stub ;;\" >> /data/adb/magisk"'
adb shell 'su -c "echo \"esac\" >> /data/adb/magisk"'
adb shell su -c "chmod 755 /data/adb/magisk"
echo "Magisk stub created. Testing:"
adb shell su -c "/data/adb/magisk --path"
echo ""

echo "[4] Find truncate error source..."
adb shell su -c "grep -rn 'truncate' /data/adb/modules/*/post-fs-data.sh /data/adb/modules/*/service.sh 2>/dev/null"
echo ""

echo "[5] Check meta-hybrid post-fs-data.sh..."
adb shell su -c "cat /data/adb/modules/meta-hybrid/post-fs-data.sh"
echo ""

echo "[6] Running ksud post-fs-data (with 10s timeout)..."
timeout 10 adb shell su -c "/data/adb/ksud post-fs-data 2>&1" > /tmp/ksud_post_fs.log &
KSUD_PID=$!
echo "ksud running in background (PID: $KSUD_PID)..."
sleep 11
if kill -0 $KSUD_PID 2>/dev/null; then
    echo "WARNING: ksud still running after 10s, killing..."
    kill $KSUD_PID 2>/dev/null
    echo "RESULT: ksud HUNG - this is the problem!"
else
    echo "ksud completed. Output:"
    cat /tmp/ksud_post_fs.log
fi
echo ""

echo "[7] Check if modules loaded..."
adb shell su -c "cat /data/adb/modules/.tmp_modules_state 2>/dev/null || echo 'STATE FILE NOT CREATED'"
echo ""

echo "[8] Check mounts..."
adb shell su -c "mount | grep -E 'overlay|modules' || echo 'NO OVERLAY MOUNTS'"
echo ""

echo "[9] Module list from ksud..."
adb shell su -c "/data/adb/ksud module list"
echo ""

echo "[10] Run services stage..."
adb shell su -c "/data/adb/ksud services 2>&1"
echo ""

echo "[11] Check final state..."
adb shell su -c "ls -la /data/adb/modules/"
adb shell su -c "mount | grep overlay | wc -l"
echo ""

echo "[12] Kernel source check - does it exec ksud?"
cd ~/kernel_xiaomi_ysl
echo "Searching for ksud exec in kernel code..."
grep -rn "ksud.*post-fs-data\|call_usermodehelper.*ksud" KernelSU/kernel/ 2>/dev/null | head -10
echo ""

echo "=== Done ==="
