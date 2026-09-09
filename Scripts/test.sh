#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build
swiftc Sources/CloudDock/Widgets/DockWidget.swift \
    Sources/CloudDock/App/DockRefreshPolicy.swift \
    Sources/CloudDock/Services/CommandRunner.swift \
    Sources/CloudDock/Services/BatteryStatusService.swift \
    Tests/CloudDockTests/RefreshPolicyTests.swift \
    -o .build/regression-tests
.build/regression-tests
