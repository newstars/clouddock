# DMG Release / DMG 배포

Current automation creates an ad-hoc signed development preview, not a notarized production release. / 현재 자동화는 개발용 임시 서명 프리뷰를 생성하며 공증된 정식 배포가 아닙니다.

1. Push reviewed changes, then run **Actions > Draft DMG Release** on the intended branch with a new `X.Y.Z` version. / 검토한 코드를 푸시하고 해당 브랜치에서 새 버전으로 워크플로를 실행합니다.
2. The package job builds arm64 and x86_64 and verifies the app and DMG. A separate job uploads the DMG/checksum to a draft prerelease. / 두 아키텍처와 DMG를 검증한 후 별도 작업이 초안 프리릴리스에 파일을 올립니다.
3. Test drag-to-Applications installation on real Apple Silicon and Intel Macs. Cross-compilation is not Intel runtime validation. / 각 실제 기기에서 설치를 검증합니다. 교차 빌드는 Intel 실행 검증이 아닙니다.
4. Verify permissions, placement, reordering, playback, and idle resource use. Record actual results and known issues in bilingual release notes before publishing the draft. / 권한·위치·정렬·음악·유휴 부하를 검증하고 결과와 미해결 문제를 한·영 노트에 기록한 뒤 공개합니다.

Duplicate version names fail instead of replacing assets. Drafts are not publicly downloadable. / 중복 버전은 기존 파일을 덮어쓰지 않고 실패합니다. 초안은 일반 사용자에게 공개되지 않습니다.

## Local / 로컬

```sh
VERSION=0.1.0 UNIVERSAL=1 bash Scripts/package_dmg.sh
```

Without UNIVERSAL=1, only the host architecture is built. The DMG includes the app, Applications link, and license. SHA-256 verifies integrity, not publisher identity. / UNIVERSAL=1이 없으면 현재 기기 아키텍처만 빌드합니다. DMG에는 앱·Applications 링크·라이선스가 포함됩니다. 체크섬은 무결성 확인용이지 배포자 인증이 아닙니다.

## Production Gate / 정식 배포 전

Developer ID signing, hardened runtime with appropriate Apple Events entitlements, notarization, stapling, and Gatekeeper assessment remain unimplemented release requirements. Setting CODESIGN_IDENTITY alone does not implement this pipeline. Do not label these builds notarized or recommend globally disabling Gatekeeper.

Developer ID 서명, 필요한 Apple Events entitlement를 포함한 hardened runtime, 공증, stapling 및 Gatekeeper 검증은 미구현 배포 요건입니다. CODESIGN_IDENTITY 설정만으로 완성되지 않습니다. 공증된 앱으로 안내하거나 Gatekeeper 전역 해제를 권하지 마세요.
