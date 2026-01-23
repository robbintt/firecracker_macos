# Troubleshooting

Common issues and solutions for the firecracker_macos project.

## Build Issues

### Kernel Build Fails

**Problem**: Kernel build fails with compilation errors

**Solutions**:
1. **Check dependencies**:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install build-essential flex bison libelf-dev libssl-dev bc
   ```

2. **Check disk space**:
   ```bash
   df -h
   ```
   Need at least 5-10 GB free for kernel build.

3. **Check GCC version**:
   ```bash
   gcc --version
   ```
   Need GCC 8.0 or later for kernel 6.x.

4. **Clean and rebuild**:
   ```bash
   cd kernel
   rm -rf build
   ./build-kernel.sh
   ```

### Rootfs Build Fails

**Problem**: `build-rootfs.sh` fails with mount errors

**Solutions**:
1. **Run with sudo**:
   ```bash
   sudo ./build-rootfs.sh
   ```

2. **Check existing mounts**:
   ```bash
   mount | grep rootfs
   ```
   If found, unmount:
   ```bash
   sudo umount /tmp/rootfs-mount-*
   ```

3. **Check loop devices**:
   ```bash
   losetup -a
   ```
   If too many, cleanup:
   ```bash
   sudo losetup -D
   ```

**Problem**: Download fails or is very slow

**Solutions**:
1. **Use different Alpine mirror**:
   Edit `rootfs/build-rootfs.sh` and change `ALPINE_MIRROR`:
   ```bash
   ALPINE_MIRROR="https://mirrors.edge.kernel.org/alpine"
   ```

2. **Download manually**:
   ```bash
   wget https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.0-x86_64.tar.gz
   ```

### macOS Build Fails

**Problem**: Swift build fails with "module not found"

**Solutions**:
1. **Update Xcode Command Line Tools**:
   ```bash
   xcode-select --install
   ```

2. **Check Swift version**:
   ```bash
   swift --version
   ```
   Need Swift 5.9+ (comes with Xcode 15.0+)

3. **Update macOS**:
   Need macOS 13.0 (Ventura) or later.

4. **Clean build**:
   ```bash
   cd macos
   rm -rf .build
   ./build.sh
   ```

**Problem**: "Virtualization framework not available"

**Solution**: Virtualization.framework requires macOS 13.0+. Update macOS.

## Runtime Issues

### Linux: Firecracker Not Found

**Problem**: `firecracker command not found`

**Solution**: Install Firecracker:
```bash
ARCH="x86_64"
VERSION="v1.7.0"
curl -LOJ https://github.com/firecracker-microvm/firecracker/releases/download/${VERSION}/firecracker-${VERSION}-${ARCH}.tgz
tar -xzf firecracker-${VERSION}-${ARCH}.tgz
sudo mv release-${VERSION}-${ARCH}/firecracker-${VERSION}-${ARCH} /usr/local/bin/firecracker
sudo chmod +x /usr/local/bin/firecracker
```

### Linux: Permission Denied on /dev/kvm

**Problem**: `Permission denied` when accessing `/dev/kvm`

**Solutions**:
1. **Add user to kvm group**:
   ```bash
   sudo usermod -aG kvm $USER
   newgrp kvm
   ```

2. **Or temporarily allow access** (development only):
   ```bash
   sudo chmod 666 /dev/kvm
   ```

3. **Check KVM is loaded**:
   ```bash
   lsmod | grep kvm
   ```
   If not loaded:
   ```bash
   sudo modprobe kvm
   sudo modprobe kvm_intel  # or kvm_amd
   ```

### Linux: TAP Device Errors

**Problem**: Network errors related to TAP device

**Solutions**:
1. **Create TAP device**:
   ```bash
   sudo ip tuntap add tap0 mode tap
   sudo ip addr add 172.16.0.1/24 dev tap0
   sudo ip link set tap0 up
   ```

2. **Or disable networking**:
   Edit `linux/linux-vm-boot` and comment out the `network-interfaces` section.

3. **Check TAP device exists**:
   ```bash
   ip link show tap0
   ```

### macOS: VM Fails to Start

**Problem**: VM fails to start with "validation error"

**Solutions**:
1. **Check kernel file**:
   ```bash
   file kernel/vmlinux
   ```
   Should show: `ELF 64-bit LSB executable, x86-64`

2. **Check rootfs file**:
   ```bash
   file rootfs/rootfs.ext4
   ```
   Should show: `Linux rev 1.0 ext4 filesystem`

3. **Check paths are correct**:
   ```bash
   ls -l kernel/vmlinux rootfs/rootfs.ext4
   ```

4. **Try with more memory**:
   ```bash
   ./macos-vm-boot --kernel vmlinux --rootfs rootfs.ext4 --memory 256
   ```

**Problem**: "Entitlement not found" or similar security error

**Solution**: This is expected in some macOS security configurations. The app should still work, but may require:
1. Running from Terminal (not automated scripts)
2. Granting Terminal full disk access in System Preferences
3. Disabling SIP for development (not recommended for production)

### VM Boots But No Console Output

**Problem**: VM appears to start but no output is shown

**Solutions**:

**Linux**:
1. **Check boot args include console**:
   Edit `linux/linux-vm-boot` and verify:
   ```
   "boot_args": "console=ttyS0 ... root=/dev/vda rw"
   ```

2. **Check kernel config**:
   ```bash
   grep CONFIG_SERIAL_8250 kernel/microvm-kernel.config
   ```

**macOS**:
1. **Check boot args include console**:
   Edit `macos/Sources/macos-vm-boot/VMManager.swift` and verify:
   ```swift
   bootloader.commandLine = "console=hvc0 root=/dev/vda rw"
   ```

2. **Check kernel config**:
   ```bash
   grep CONFIG_VIRTIO_CONSOLE kernel/microvm-kernel.config
   grep CONFIG_HVC_DRIVER kernel/microvm-kernel.config
   ```

### VM Boots But Kernel Panic

**Problem**: Kernel panics with "not syncing: VFS: Unable to mount root fs"

**Solutions**:
1. **Check rootfs path is correct**:
   ```bash
   ls -lh rootfs/rootfs.ext4
   ```

2. **Check ext4 support in kernel**:
   ```bash
   grep CONFIG_EXT4_FS kernel/microvm-kernel.config
   ```

3. **Rebuild rootfs**:
   ```bash
   cd rootfs
   sudo rm rootfs.ext4
   sudo ./build-rootfs.sh
   ```

4. **Check boot args**:
   Should include `root=/dev/vda` (virtio block device)

### VM Boots But Networking Doesn't Work

**Problem**: Network interface doesn't come up or no connectivity

**Solutions**:

**Check interface exists**:
```bash
# Inside VM
ip link show
```

**Linux host**:
1. **Set up TAP device with routing**:
   ```bash
   sudo ip tuntap add tap0 mode tap
   sudo ip addr add 172.16.0.1/24 dev tap0
   sudo ip link set tap0 up
   sudo sysctl -w net.ipv4.ip_forward=1
   sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
   ```

2. **Configure DHCP inside VM**:
   ```bash
   # Inside VM
   udhcpc -i eth0
   ```

**macOS host**:
Network should work automatically with NAT. If not:
1. Check that networking is enabled in `VMManager.swift`
2. Try pinging the host gateway

### Slow Boot Times

**Problem**: VM takes a long time to boot

**Solutions**:
1. **Reduce kernel size**: Remove unnecessary drivers from config
2. **Reduce rootfs size**: Use smaller base image
3. **Check host resources**: Ensure host isn't resource-constrained
4. **Disable unnecessary services**: In guest init system

### Build Artifacts Too Large

**Problem**: Kernel or rootfs is larger than expected

**Solutions**:

**Kernel too large** (>30 MB):
1. Review `kernel/microvm-kernel.config`
2. Disable debugging: Remove `CONFIG_DEBUG_*` options
3. Disable unused filesystems
4. Strip kernel:
   ```bash
   strip -s kernel/vmlinux
   ```

**Rootfs too large** (>100 MB used):
1. Remove unnecessary packages
2. Clean package cache:
   ```bash
   # Inside chroot during build
   apk cache clean
   ```

## Testing Issues

### Tests Fail to Run

**Problem**: `test-boot.sh` fails

**Solutions**:
1. **Ensure artifacts are built**:
   ```bash
   test -f kernel/vmlinux || echo "Build kernel first"
   test -f rootfs/rootfs.ext4 || echo "Build rootfs first"
   ```

2. **Ensure wrappers are built**:
   ```bash
   # Linux
   test -x linux/linux-vm-boot || echo "linux-vm-boot not executable"
   
   # macOS
   test -x macos/macos-vm-boot || echo "Build macOS wrapper first"
   ```

3. **Run from project root**:
   ```bash
   cd /path/to/firecracker_macos
   ./tests/test-boot.sh
   ```

### CI Pipeline Fails

**Problem**: GitHub Actions workflow fails

**Solutions**:

**Kernel build timeout**:
- Increase timeout in workflow
- Use cached kernel build

**No KVM access**:
- Expected in GitHub Actions
- Tests should gracefully skip full VM boot

**macOS runner unavailable**:
- Check GitHub Actions quotas
- macOS runners may have limited availability

## Getting Help

If you encounter an issue not covered here:

1. **Check logs**: Look for error messages in console output
2. **Check kernel logs**: Use `dmesg` inside the VM
3. **Verify configuration**: Compare with working examples
4. **Search issues**: Check GitHub issues for similar problems
5. **File an issue**: Provide:
   - Platform (macOS/Linux)
   - OS version
   - Error messages
   - Steps to reproduce
