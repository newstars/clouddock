#!/usr/bin/env bash
set -euo pipefail

swift build
swift build -c release
SKIP_BUILD=1 Scripts/package_app.sh
Scripts/verify_app_bundle.sh
