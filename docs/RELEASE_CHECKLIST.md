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

## Remaining / 남은 항목

- [ ] Full source review: security, credentials, cancellation, persistence, unused/duplicate features.
- [ ] Long-running CPU/RSS and wake/sleep measurements; no leak-free claim yet.
- [ ] All optional widgets disabled: verify no unexpected network/command work.
- [ ] Music scripting: nonblocking execution, permission denial, missing queue/artwork, restart.
- [ ] Audio and Calendar device/permission changes; Weather offline/cancellation.
- [ ] Datadog live-account integration, pagination, disconnect and invalid credentials.
- [ ] Drag/reorder, nested popovers, settings singleton, and position persistence UI regression.
- [ ] Multi-monitor, display removal, resolution changes, and macOS Dock positions.
- [ ] Intel and Apple Silicon clean-install runtime tests.
- [ ] Developer ID signing, hardened runtime, notarization, stapling, Gatekeeper assessment.
- [ ] Final bilingual README/known-issues reconciliation and public DMG release.

Automated checks run via CI. Hardware, account, and Apple signing checks need their respective environments; missing access must not be treated as a pass.
자동 테스트는 CI에서 실행합니다. 실기기·계정·Apple 서명 검증은 해당 환경이 필요하며, 접근할 수 없다는 이유로 통과 처리하지 않습니다.
