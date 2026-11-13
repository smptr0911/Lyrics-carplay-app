# Spotify와 음악 앱 선택

검토: 2026-11-12. Settings → Music app에서 Spotify / Apple Music / Demo를 선택합니다. 선택값을 저장하며 기본값은 Spotify입니다. Apple Music은 권한 요청만 구현되어 있습니다. 시뮬레이터에서는 Demo를 사용하세요.

## 구현 범위

공식 SpotifyiOS App Remote SDK 5.0.1을 고정했습니다. 인증, 곡·아티스트·앨범, 보고된 재생 위치, 재생·일시정지와 허용된 탐색을 연결합니다. 이미지 로딩은 미구현입니다. 위치를 임의로 보간하지 않습니다.

Open Spotify / Resume를 누르면 Spotify가 열리고 최근 곡이 재개될 수 있습니다. 비활성 시 해제하고 활성 시 메모리 토큰으로 재연결합니다. 소스 변경은 이전 인증·토큰·가사 상태를 정리하되 기존 Spotify 재생을 임의로 정지하지 않습니다. 앱 종료 후 재인증이 필요합니다. 토큰과 callback URL을 로그·UserDefaults에 보관하지 않습니다. callback은 등록된 주소 및 최근 사용자 인증 요청과 일치할 때만 처리합니다. 앱 전환 인증은 SDK가 관리합니다.

## 설정

1. Spotify Developer Dashboard에서 앱을 만들고 실제 번들 ID와 iOS SDK 사용을 등록합니다. 계정·개발 모드 제한은 현재 대시보드에서 확인합니다.
2. App Remote redirect URI를 `lyrics-carplay-spotify://callback`으로 등록합니다. 독립 Web API OAuth 규칙과 혼동하지 말고 해당 iOS SDK 흐름으로 검증합니다. scheme을 바꾸려면 SpotifyConfiguration, 두 Info plist와 대시보드를 함께 변경하세요.
3. `Config/Local.xcconfig.example`을 `Config/Local.xcconfig`로 복사하고 공개 Client ID를 입력합니다. Client Secret은 앱에 넣지 않습니다. Local 파일은 Git에서 제외됩니다.
4. Xcode에서 패키지를 resolve합니다. App.xcconfig, 두 plist의 SpotifyClientID·URL scheme·조회 설정과 -ObjC 플래그가 구성되어 있습니다.
5. Spotify가 설치되고 로그인된 실제 iPhone에서 연결 버튼을 누릅니다. 시뮬레이터는 Spotify 앱 실연결을 대체하지 못합니다.
6. 곡 변경·탐색 제한·재연결·권한 철회·소스 변경 중 callback을 검증합니다. UI 테스트는 `--demo-mode`로 시작합니다. CarPlay 목록은 정적 데모로 남아 있습니다.

## 정책 제약

[Spotify Compliance Tips](https://developer.spotify.com/compliance-tips)는 Spotify 녹음과 가사·영상 등의 동기화를 금지 사례로 명시합니다. Spotify 선택 시 가사 요청·표시·강조를 차단합니다. 별도의 가사 계약만으로 이 제한이 해제되지는 않습니다. Spotify 음악과 주차 영상을 동기화하지 않습니다.

[Developer Policy](https://developer.spotify.com/policy)의 다른 서비스 통합·상용화 제한도 최종 제품 배포 전 검토해야 합니다. 이번 코드는 정책 승인이 아닙니다. Spotify 중심의 동기화 가사 제품은 별도 허용 근거가 없으면 현재 요구사항 그대로 출시할 수 없습니다.

Windows 구조 검증은 통과했습니다. Xcode 컴파일·실제 인증·기기 재생은 미검증입니다.

- [SDK와 실제 기기 요구사항](https://developer.spotify.com/documentation/ios)
- [설정·인증·상태 구독](https://developer.spotify.com/documentation/ios/getting-started)
- [앱 수명주기](https://developer.spotify.com/documentation/ios/concepts/application-lifecycle)
- [공식 패키지](https://github.com/spotify/ios-sdk/blob/v5.0.1/Package.swift)
