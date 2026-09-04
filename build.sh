#!/bin/bash
set -e
echo "Downloading Flutter..."
curl -s -O https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.24.5-stable.tar.xz
tar xf flutter_linux_3.24.5-stable.tar.xz
export PATH="$PATH:`pwd`/flutter/bin"
flutter config --no-analytics
flutter pub get
flutter build web --release --base-href /
cp web/_redirects build/web/ || true
echo "Build complete!"
