#!/bin/sh
# Guest test script - runs inside the VM to validate functionality

echo ""
echo "=== Guest VM Test Script ==="
echo ""

# Test basic system info
echo "Testing system information..."
echo "  Hostname: $(hostname)"
echo "  Kernel: $(uname -r)"
echo "  Architecture: $(uname -m)"

# Test memory
echo ""
echo "Testing memory..."
TOTAL_MEM=$(free -m | grep Mem | awk '{print $2}')
echo "  Total Memory: ${TOTAL_MEM}MB"

# Test disk
echo ""
echo "Testing disk..."
ROOT_SIZE=$(df -h / | tail -1 | awk '{print $2}')
ROOT_AVAIL=$(df -h / | tail -1 | awk '{print $4}')
echo "  Root Size: ${ROOT_SIZE}"
echo "  Root Available: ${ROOT_AVAIL}"

# Test /dev/vda (root device)
if [ -b /dev/vda ]; then
    echo "  ✓ /dev/vda exists (virtio block device)"
else
    echo "  ✗ /dev/vda not found"
    exit 1
fi

# Test console
echo ""
echo "Testing console..."
if [ -c /dev/hvc0 ] || [ -c /dev/ttyS0 ]; then
    echo "  ✓ Console device found"
else
    echo "  ✗ No console device found"
    exit 1
fi

# Test network interface
echo ""
echo "Testing network..."
if ip link show eth0 > /dev/null 2>&1; then
    echo "  ✓ eth0 interface exists"
    IP_ADDR=$(ip -4 addr show eth0 | grep inet | awk '{print $2}')
    if [ -n "$IP_ADDR" ]; then
        echo "  ✓ IP Address: ${IP_ADDR}"
    else
        echo "  ⚠ No IP address assigned (may need DHCP)"
    fi
else
    echo "  ⚠ eth0 interface not found (networking may not be configured)"
fi

# Test entropy device
echo ""
echo "Testing entropy..."
if [ -c /dev/random ]; then
    echo "  ✓ /dev/random exists"
    # Try to read a few bytes
    dd if=/dev/random of=/tmp/random-test bs=16 count=1 2>/dev/null
    if [ $? -eq 0 ]; then
        echo "  ✓ Can read from /dev/random"
        rm /tmp/random-test
    fi
else
    echo "  ✗ /dev/random not found"
fi

# Test write to disk
echo ""
echo "Testing disk write..."
TEST_FILE="/tmp/disk-write-test"
echo "test data" > "$TEST_FILE"
if [ -f "$TEST_FILE" ]; then
    CONTENT=$(cat "$TEST_FILE")
    if [ "$CONTENT" = "test data" ]; then
        echo "  ✓ Disk write successful"
        rm "$TEST_FILE"
    else
        echo "  ✗ Disk write verification failed"
        exit 1
    fi
else
    echo "  ✗ Could not create test file"
    exit 1
fi

# Test basic commands
echo ""
echo "Testing basic commands..."
for cmd in ls cat grep sed awk; do
    if command -v $cmd > /dev/null 2>&1; then
        echo "  ✓ $cmd available"
    else
        echo "  ✗ $cmd not found"
    fi
done

echo ""
echo "=== All Tests Passed ==="
echo ""
echo "You can now shut down with: poweroff"
