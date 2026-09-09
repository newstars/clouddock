#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
mkdir -p .build
swiftc Sources/CloudDock/Widgets/DockWidget.swift \
    Sources/CloudDock/App/DockRefreshPolicy.swift \
    Sources/CloudDock/Services/CommandRunner.swift \
    Sources/CloudDock/Services/BatteryStatusService.swift \
    Sources/CloudDock/Services/NetworkStatsService.swift \
    Sources/CloudDock/Services/ClipboardService.swift \
    Sources/CloudDock/Widgets/Pomodoro/CountdownTimer.swift \
    Sources/CloudDock/Widgets/Music/MusicScriptExecutor.swift \
    Sources/CloudDock/Widgets/Music/MusicWidgetModel.swift \
    Tests/CloudDockTests/MusicScriptTests.swift \
    Tests/CloudDockTests/MusicModelTests.swift \
    Tests/CloudDockTests/ClipboardTests.swift \
    Tests/CloudDockTests/CommandRunnerTests.swift \
    Tests/CloudDockTests/BackgroundRefreshTests.swift \
    Tests/CloudDockTests/RefreshPolicyTests.swift \
    -o .build/regression-tests
.build/regression-tests
