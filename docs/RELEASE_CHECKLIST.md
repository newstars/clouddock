# Release Gate / 공개 완료 기준

Status: in progress. Passing a build is not completion of this checklist.
상태: 진행 중. 빌드 성공만으로 공개 준비가 완료되지 않습니다.

## Completed With Local Evidence / 로컬 검증 완료

- [x] Hidden/disabled-widget refresh policy and privacy-mode regression checks.
- [x] Background process/Git polling with one in-flight refresh.
- [x] Battery charging/discharging parser regression checks.
- [x] Clipboard full-text restoration, 10-entry/64-KiB-per-entry bounds, concealed-type exclusion, deduplication, clear-history checks using an isolated pasteboard.
- [x] Command success/failure, output bounds, timeout, and stderr-drainage regression checks.
- [x] Universal DMG cross-build and read-only mount verified in the preceding packaging pass (not Intel runtime validation).

## Execution Order / 하나씩 완료할 순서

Each ID is closed only with the evidence in its row. Automated tests do not close hardware/UI checks. Work on one ID, record its result, then move to the next. A blocked account/hardware step stays open while independent work proceeds.

각 ID는 표에 적힌 근거가 확보되어야 완료합니다. 자동 테스트로 실기기·UI 항목까지 완료 처리하지 않습니다. 한 항목의 결과를 기록한 후 다음으로 넘어가며, 계정·기기 접근이 필요한 항목은 미완료로 유지하고 독립적인 작업을 진행합니다.

| ID | 상태 / Status | 작업 / Task | 완료 조건 / Required Evidence |
| --- | --- | --- | --- |
| A1 | 완료 / Done | Battery/network polling off MainActor | `BackgroundRefreshTests`: delayed loaders do not block MainActor, single-flight, failure/retry. Full CI passes. |
| A2 | 다음 / Next | Music script execution off MainActor | Slow script cannot freeze dock; serialization and error-state tests; normal playback smoke test. |
| A3 | 대기 / Open | Music denied permission, empty queue, missing artwork, app restart | Reproducible fixture tests plus runtime checks; no unsolicited app activation. |
| A4 | 대기 / Open | Disabled/hidden widget work | Instrument all command/network entry points; prove disabled widgets make no new requests. In-flight work reported separately. |
| A5 | 대기 / Open | Idle and visible resource use | Record build, enabled widgets, hardware, sampling method and at least 30 minutes of CPU/RSS; inspect growth, do not infer no leaks from one sample. |
| A6 | 대기 / Open | Sleep/wake | Real sleep/wake test: timer, polling, and UI recover without burst or stall. |
| B1 | 대기 / Open | Process termination safeguards | Own test process only; stale identity/protected process/failure states; visible error on failure. |
| B2 | 대기 / Open | Persistence and secret storage | Review each store, corrupt/missing data tests; no credentials in defaults/logs; Keychain failure surfaced. |
| B3 | 대기 / Open | Datadog lifecycle and pagination | Mock invalid keys, reconnect, disconnect during load, duplicate pages; separate live-account read-only check. |
| B4 | 대기 / Open | Weather cancellation/offline | Rapid city changes cannot apply stale result; offline errors and retry; privacy review of requests. |
| B5 | 대기 / Open | Calendar authorization/events | Granted/denied/revoked states and meeting links; actual macOS permission flow. |
| B6 | 대기 / Open | Audio devices | Device removal/default change/read-only volume: correct UI and no crash. |
| C1 | 대기 / Open | Settings and popovers | One settings window, Escape/outside click, no dock resize, no clipped lists. |
| C2 | 대기 / Open | Drag and order persistence | App, group, widget reordering and cancellation; same order after restart. |
| C3 | 대기 / Open | Window positioning | Move/reopen/resize and each preset; no snap-back. |
| C4 | 대기 / Open | Multiple monitors and macOS Dock | Screen removal/resolution change; left/right/bottom Dock; real multi-display evidence. |
| C5 | 대기 / Open | Duplication and large modules | Inventory dead/redundant paths; split only justified ownership boundaries; tests pass without behavior changes. |
| D1 | 대기 / Open | Clean installation | Current DMG on Apple Silicon and Intel; copied app launches from Applications. Cross-build alone does not pass. |
| D2 | 대기 / Open | Developer ID and entitlements | Valid signing identity, least-privilege hardened-runtime entitlements, permission-flow verification. |
| D3 | 대기 / Open | Notarization | Accepted notarization, stapling, Gatekeeper assessment of downloaded artifact. |
| D4 | 대기 / Open | Public release | README matches actual verification; bilingual known issues; final checksum/DMG published after remaining release blockers resolved. |

## Latest Result / 최근 결과

2026-09-09, A1: Battery and network services now publish state on MainActor but run their fixed commands in utility tasks. One refresh per service is allowed at a time. A failed network sample clears its prior baseline instead of calculating against stale data. Controlled delayed-output tests cover responsiveness, duplicate requests, and retries. No live battery-device or long-duration claim is made by this result.

2026-09-09, A1: 배터리·네트워크는 UI 상태만 메인 스레드에서 변경하고 명령은 백그라운드에서 실행합니다. 중복 요청을 막고, 네트워크 조회 실패 시 오래된 비교 기준을 초기화합니다. 지연 응답 기반으로 응답성·중복·재시도를 검증했습니다. 실제 배터리 기기 및 장시간 검증까지 완료했다는 뜻은 아닙니다.

Automated checks run via CI. Hardware, account, and Apple signing checks need their respective environments; missing access must not be treated as a pass.
자동 테스트는 CI에서 실행합니다. 실기기·계정·Apple 서명 검증은 해당 환경이 필요하며, 접근할 수 없다는 이유로 통과 처리하지 않습니다.
