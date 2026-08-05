#!/bin/bash
#
# bump-build.sh — increment the build number for the next TestFlight / App Store upload.
#
# Each upload to App Store Connect needs a unique build number (CFBundleVersion).
# The marketing version (e.g. 1.0) stays the same until you ship a new public version.
#
# Usage:
#   ./scripts/bump-build.sh          # 1 -> 2 -> 3 ...
#
set -e
cd "$(dirname "$0")/.."
xcrun agvtool next-version -all >/dev/null
echo "Build number is now: $(xcrun agvtool what-version -terse)"
echo "Marketing version:   $(xcrun agvtool what-marketing-version -terse | head -1 | sed 's/.*=//')"
echo
echo "Next: Product > Archive in Xcode, then Organizer > Distribute App > App Store Connect."
