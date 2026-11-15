# Mac에서 이어서 검증하기

사용자 확인: Mac/Xcode와 실제 iPhone 사용 가능. Spotify 개발자 앱은 아직 생성되지 않음. 현재 작업 환경은 Windows이므로 iOS 빌드 성공 여부는 아직 확인하지 않았습니다.

## 코드 가져오기

파일 복사 없이 GitHub에서 받으려면 [Mac 시작 안내](mac-start.md)를 따릅니다. Mac 개발 브랜치는 development/mac-xcode입니다. 아래 ZIP 방식은 선택 사항입니다.

현재 작업 파일은 아직 Git에 커밋·푸시되지 않았을 수 있습니다. 원격 저장소를 clone하는 것만으로 이번 코드가 모두 내려온다고 가정하지 마세요. 생성된 소스 ZIP을 Mac에 옮겨 압축 해제하거나, 변경을 검토한 뒤 본인이 커밋·푸시한 버전을 가져오면 됩니다.

소스 ZIP 재생성:

```sh
python scripts/package_source.py
```

생성 위치는 .build/LyricsCarPlay-source.zip입니다. Git 메타데이터, 로컬 설정, 빌드 결과, Python 캐시는 포함하지 않습니다. ZIP은 앱 설치 파일이 아닙니다.

## 빌드와 테스트

1. Xcode 16 이상, iOS 17 이상 iPhone 시뮬레이터, Python 3.10 이상을 준비합니다.
2. Xcode를 처음 실행해 추가 구성요소를 설치하고 사용할 Xcode를 선택합니다.
3. 프로젝트 루트에서 아래 명령을 실행합니다.

```sh
bash scripts/verify_on_mac.sh
```

이 명령은 구조 검사, 설치된 호환 iPhone 시뮬레이터에서 단위/UI 테스트, 서명 없는 실제 기기용 Release 컴파일을 순서대로 수행합니다. 로그는 .build/logs에 남습니다. 실제 기기 설치와 CarPlay 창 검증은 별도입니다. 실행 실패 시 최초 Swift 오류부터 수정해야 하며, 구조 검사 통과만으로 빌드가 통과한 것은 아닙니다.

## iPhone 설치

1. Config/Local.xcconfig.example을 Local.xcconfig로 복사합니다.
2. APP_BUNDLE_IDENTIFIER를 본인의 고유 App ID로, DEVELOPMENT_TEAM을 본인 팀 ID로 설정합니다. 기본 org.example ID는 배포용으로 확정한 값이 아닙니다.
3. Xcode에서 iPhone을 선택하고 Signing & Capabilities의 자동 서명과 팀을 확인합니다.
4. 필요한 기기 개발 모드·신뢰 설정을 완료하고 Run 합니다.
5. 첫 실행에서 Demo를 선택해 재생·탐색·스크롤·다크 모드·개인정보 화면을 확인합니다.
6. Spotify는 [개발자 앱 생성](spotify-setup.md) 후 연결합니다. Apple Music은 해당 App ID의 MusicKit App Service를 활성화하고 권한·구독·현재 큐 동작을 검증합니다. 임의의 MusicKit entitlement를 추가하지 않습니다.

CarPlay는 [시뮬레이터 안내](carplay-simulator.md), 영상은 [차량 점검](parked-video.md), 로컬 API는 [서버 안내](../backend/README.md)를 따릅니다.
