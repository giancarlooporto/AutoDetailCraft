#!/bin/bash
set -e
echo "Cloning Flutter stable SDK..."
git clone -b stable --depth 1 https://github.com/flutter/flutter.git
export PATH="$PATH:`pwd`/flutter/bin"
flutter --version
flutter config --no-analytics
flutter pub get
flutter build web --release --base-href /
echo "Build complete!"
