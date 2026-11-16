# Mac에서 CarPlay 시뮬레이터 실행

## 현재 환경 확인

이 프로젝트를 확인한 환경은 다음과 같습니다.

- Xcode 27.2 (`27B52`)
- macOS 27.0.1
- USB로 연결된 iPhone 14 Pro (`00008120-0012491C3EEB401E`)
- iPhone 상태: paired이지만 Developer Mode 비활성화

확인 명령:

```bash
xcode-select -p
xcodebuild -version
xcrun simctl list devices available
xcrun devicectl list devices
```

실제 iPhone을 개발 대상으로 사용하려면 iPhone에서 **Settings → Privacy & Security
→ Developer Mode**를 켜고 재시동해야 합니다. Xcode가 기기를 표시하더라도 Developer
Mode가 꺼져 있으면 빌드·디버깅 대상이 될 수 없습니다.

시뮬레이터 전용 장면에서 데모 곡 목록과 상세 화면을 탐색할 수 있습니다. 실제
Spotify·오디오·가사·차량 영상 재생은 이 목록에 연결되어 있지 않습니다.

## Xcode 27.2에서 실제 iPhone 연결

Apple의 [CarPlay Simulator 문서](https://developer.apple.com/documentation/carplay/using-the-carplay-simulator)와
[Xcode 27.2 Release Notes](https://developer.apple.com/documentation/xcode-release-notes/xcode-27_2-release-notes)를
기준으로, Device Hub 방식은 **USB로 연결된 실제 iPhone을 CarPlay 소스로 사용하는
흐름**입니다. iOS Simulator를 Device Hub의 실제 iPhone 소스로 바꾸는 기능은 아닙니다.

1. iPhone의 암호를 해제하고 Mac을 신뢰한 뒤 Developer Mode를 켭니다.
2. Xcode에서 `LyricsCarPlay` 스킴과 연결된 iPhone을 선택합니다.
3. Signing & Capabilities에서 본인의 Team과 등록된 Bundle Identifier를 확인합니다.
4. `⌘R`로 일반 iPhone 앱을 먼저 설치·실행합니다.
5. Xcode 27.2의 Device Hub에서 연결된 iPhone을 선택하고 제공되는 CarPlay
   연결/디스플레이 세션을 시작합니다. 설치된 Xcode에서 해당 항목이 표시되지 않으면
   프로젝트 설정으로 메뉴를 만들거나 entitlement를 우회할 수 없습니다.

현재 프로젝트는 실제 기기 빌드에 CarPlay Scene과 entitlement를 포함하지 않습니다.
Apple의 category-specific CarPlay 승인이 없는 상태에서 이를 임의로 추가하지 않습니다.
따라서 승인 전에는 위 절차로 일반 iPhone 동작만 검증할 수 있습니다.

## 전통적인 Simulator 방식

전통적인 방식은 iOS Simulator에서 앱을 실행한 뒤 Simulator 메뉴의
`I/O → External Displays → CarPlay`를 여는 것입니다. Xcode 27.2 설치 환경에서는
이 메뉴가 표시되지 않을 수 있으며, 이 경우 Device Hub의 실제 iPhone 흐름과
혼동하지 마십시오. 해당 메뉴가 필요하면 Apple이 지원하는 호환 Xcode/macOS
조합을 별도 개발 환경에서 사용해야 합니다.

메뉴가 표시되는 환경에서는 다음 순서로 확인합니다.

1. `CarPlay Simulator` 스킴과 iPhone Simulator를 선택해 Run 합니다.
2. `I/O → External Displays → CarPlay`를 엽니다.
3. CarPlay에서 Lyrics CarPlay를 열어 Open Road 선택·상세 화면·뒤로 가기를 확인합니다.
4. `python3 scripts/validate_project.py --xcode`로 프로젝트 검증을 실행합니다.

Info-Simulator.plist와 CarPlay-Simulator.entitlements는 시뮬레이터 SDK 조건에서만 적용합니다. 장면 소스·테스트도 시뮬레이터 전용입니다. 실제 기기·Archive는 기존 iPhone 설정을 사용합니다. 오디오 entitlement는 템플릿 탐색용이며 Apple 승인을 의미하지 않습니다.

Windows 구조 검증은 통과했습니다. Xcode 컴파일과 CarPlay 창 실행은 아직 미검증입니다.

- [장면 구성](https://developer.apple.com/documentation/carplay/displaying-content-in-carplay)
- [권한·시뮬레이터](https://developer.apple.com/documentation/carplay/requesting-carplay-entitlements)
- [도구](https://developer.apple.com/carplay/)
