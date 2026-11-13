# Spotify 개발자 앱 생성부터 실제 연결까지

먼저 확정할 공개 정보는 앱 이름, iOS 번들 ID, Spotify Client ID입니다. Client Secret이나 로그인 토큰은 제공하거나 앱에 넣지 않습니다.

1. [Spotify Developer Dashboard](https://developer.spotify.com/dashboard)에 로그인합니다.
2. 앱 생성 기능을 사용해 프로젝트용 앱을 등록합니다. 대시보드의 현재 계정·개발 모드·허용 사용자 조건을 확인합니다.
3. iOS SDK 사용을 선택하고 Xcode와 동일한 번들 ID를 등록합니다.
4. App Remote redirect URI를 `lyrics-carplay-spotify://callback`으로 정확히 등록합니다. 저장 후 표시되는 공개 Client ID를 복사합니다.
5. Config/Local.xcconfig.example을 Config/Local.xcconfig로 복사하고 다음을 본인 값으로 설정합니다.

```xcconfig
APP_BUNDLE_IDENTIFIER = com.yourcompany.lyricscarplay
DEVELOPMENT_TEAM = YOUR_TEAM_ID
SPOTIFY_CLIENT_ID = YOUR_PUBLIC_CLIENT_ID
```

6. 실제 iPhone에 Spotify를 설치하고 로그인합니다. 필요한 경우 개발자 앱의 허용 사용자 목록에 테스트 계정을 추가합니다.
7. Xcode에서 패키지를 resolve하고 iPhone에 앱을 설치합니다.
8. Settings → Music app → Spotify → Open Spotify / Resume를 누릅니다. 이 동작은 Spotify를 열고 최근 곡을 재개할 수 있습니다.
9. 인증 후 현재 곡·아티스트·재생/일시정지·탐색 제한·Spotify 링크를 확인합니다.
10. Demo로 전환해 이전 트랙이 남지 않는지, Spotify로 돌아와 재연결되는지 확인합니다. 앱 종료 후에는 다시 연결해야 합니다.

Spotify 가사는 정책 제한으로 요청·표시하지 않습니다. 주차 영상과 Spotify 음악을 동기화하지 않습니다. CarPlay의 정적 목록은 아직 Spotify 플레이어 화면이 아닙니다.

오류 점검: callback의 대소문자·주소 일치, Client ID·번들 ID, 앱 허용 사용자와 계정 상태, Spotify 설치·로그인, Xcode 빌드 설정의 값 확장을 차례대로 확인합니다. UI에 설정 미완료가 표시되면 Client ID가 앱 plist에 반영되었는지 확인하세요.

근거: [공식 iOS 시작 안내](https://developer.spotify.com/documentation/ios/getting-started), [SDK 요구사항](https://developer.spotify.com/documentation/ios), [정책](https://developer.spotify.com/compliance-tips).
