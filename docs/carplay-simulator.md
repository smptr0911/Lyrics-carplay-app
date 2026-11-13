# Mac에서 CarPlay 시뮬레이터 실행

시뮬레이터 전용 장면에서 데모 곡 목록과 상세 화면을 탐색할 수 있습니다. 실제 Spotify·오디오·가사·차량 영상 재생은 이 목록에 연결되어 있지 않습니다.

1. Xcode 16 이상과 iOS 17 이상 시뮬레이터를 설치합니다.
2. LyricsCarPlay.xcodeproj에서 CarPlay Simulator 스킴과 iPhone 시뮬레이터를 선택해 Run 합니다.
3. Simulator의 I/O → External Displays → CarPlay를 엽니다. 메뉴는 버전에 따라 다를 수 있습니다. 별도 도구는 Additional Tools for Xcode에서 받습니다.
4. CarPlay에서 Lyrics CarPlay를 열어 Open Road 선택·상세 화면·뒤로 가기를 확인합니다.
5. 창을 닫았다 열어 재연결을 확인합니다. iPhone 화면에서는 Settings에서 Demo로 기존 가사를 확인합니다.
6. `python3 scripts/validate_project.py --xcode`로 테스트합니다. 실제 장면 실행은 수동 확인이 필요합니다.

Info-Simulator.plist와 CarPlay-Simulator.entitlements는 시뮬레이터 SDK 조건에서만 적용합니다. 장면 소스·테스트도 시뮬레이터 전용입니다. 실제 기기·Archive는 기존 iPhone 설정을 사용합니다. 오디오 entitlement는 템플릿 탐색용이며 Apple 승인을 의미하지 않습니다.

Windows 구조 검증은 통과했습니다. Xcode 컴파일과 CarPlay 창 실행은 아직 미검증입니다.

- [장면 구성](https://developer.apple.com/documentation/carplay/displaying-content-in-carplay)
- [권한·시뮬레이터](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [도구](https://developer.apple.com/carplay/)
