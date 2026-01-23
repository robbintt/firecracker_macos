#!/bin/bash
set -e

echo "Building macos-vm-boot..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "Error: This build script must be run on macOS"
    exit 1
fi

# Check Swift version
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed"
    exit 1
fi

echo "Swift version:"
swift --version

# Build the project
swift build -c release

# Copy the binary to the root of the macos directory
cp .build/release/macos-vm-boot ./macos-vm-boot

echo "Build complete! Binary: macos/macos-vm-boot"
