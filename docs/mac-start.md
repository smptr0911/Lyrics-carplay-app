# 파일 복사 없이 Mac에서 시작하기

저장소: https://github.com/smptr0911/Lyrics-carplay-app
개발 브랜치: feature/ios-foundation

이 브랜치가 실제 원격에 게시된 뒤 아래 절차를 따릅니다. main에는 개발 코드가 아직 합쳐져 있지 않을 수 있습니다.

## 1. Mac 도구 준비

1. App Store에서 Xcode를 설치하고 한 번 실행합니다.
2. 라이선스 동의와 추가 구성요소 설치를 완료합니다.
3. Xcode의 Settings에서 iOS Simulator 런타임을 설치합니다. 앱의 최소 iOS 버전은 17입니다.
4. 터미널에서 `xcodebuild -version`, `git --version`, `python3 --version`을 확인합니다.
5. xcodebuild가 Command Line Tools만 선택되었다고 나오면 `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`를 실행하고 다시 확인합니다. Xcode 설치 위치가 다르면 실제 경로를 사용합니다.
6. 로컬 서버와 스크립트에는 Python 3.10 이상을 사용합니다. python3가 없다면 Python 공식 macOS 설치 프로그램으로 설치합니다.

## 2. 코드 내려받기

```sh
mkdir -p ~/Projects
cd ~/Projects
git clone --branch feature/ios-foundation https://github.com/smptr0911/Lyrics-carplay-app.git
cd Lyrics-carplay-app
git branch --show-current
open LyricsCarPlay.xcodeproj
```

비공개 저장소라면 GitHub 계정 접근이 필요합니다. 인증 오류가 나오면 비밀번호를 코드나 URL에 넣지 말고 GitHub 인증을 완료하세요. 이미 같은 폴더가 있으면 기존 작업을 덮어쓰지 말고 다른 이름으로 clone하거나 변경을 확인한 뒤 fetch/전환합니다.

## 3. 첫 시뮬레이터 실행

1. Xcode가 SpotifyiOS 패키지를 resolve할 때까지 기다립니다. 처음에는 인터넷 연결이 필요합니다.
2. 상단 스킴은 LyricsCarPlay, 실행 대상은 설치된 iPhone 시뮬레이터를 선택합니다.
3. Command-R로 실행합니다. 시뮬레이터에는 개발팀 서명이 필요하지 않습니다.
4. Welcome에서 Demo를 선택하고 Continue를 누릅니다.
5. Now Playing에서 Play/Pause, 위치 탐색, 가사 강조, 수동 스크롤과 Follow lyrics를 확인합니다.
6. Settings에서 Spotify로 바꿔 이전 데모 트랙이 사라지는지 확인합니다. 실제 Spotify 연결은 iPhone에서 수행합니다.

## 4. 자동 검사

```sh
bash scripts/verify_on_mac.sh
python3 -m unittest discover -s backend/tests -v
```

첫 명령은 구조 검사, 시뮬레이터 단위/UI 테스트, 서명 없는 기기용 Release 컴파일을 수행합니다. .build/logs/simulator.log와 device-release.log에 결과가 남습니다. 실패하면 첫 오류를 알려주세요. 이것은 물리 iPhone/차량 테스트를 대체하지 않습니다.

## 5. CarPlay 시뮬레이터

CarPlay Simulator 스킴과 iPhone 시뮬레이터를 선택해 Run한 후 Simulator 메뉴의 I/O → External Displays → CarPlay를 엽니다. 앱에서 Open Road 목록·상세 화면·뒤로 가기·재연결을 확인합니다. 이 화면은 정적 데모이며 Spotify 제어·가사·영상 재생에 연결되어 있지 않습니다. 자세한 버전별 점검은 [CarPlay 안내](carplay-simulator.md)를 보세요.

## 6. iPhone과 Spotify

[Spotify 앱 생성 안내](spotify-setup.md)를 따라 공개 Client ID와 번들 ID를 준비합니다. Config/Local.xcconfig.example을 Local.xcconfig로 복사해 본인 값을 넣고 개발팀을 설정합니다. 실제 iPhone을 선택해 설치한 뒤 Spotify에 연결합니다. Client Secret은 앱에 넣지 않습니다. [Mac 인계 안내](mac-handoff.md)에 서명·기기 점검 절차가 있습니다.

## 7. 선택 사항: 가사 개발 서버

```sh
python3 -m backend.app --port 8787
```

서버를 실행한 채 Config/Local.xcconfig에 다음을 추가하고 Debug 시뮬레이터에서 Demo를 선택합니다.

```xcconfig
LYRICS_API_URL = http:/$()/localhost:8787/v1/lyrics
```

이 경로는 시뮬레이터에서만 허용합니다. 공급자 계약 없이 실제 상용 가사를 제공하지 않습니다. [서버 안내](../backend/README.md)를 참고하세요.

## 8. Mac에서 계속 개발

VS Code를 선호하면 Mac에서도 이 폴더를 VS Code로 열어 편집하고 Xcode로 빌드하면 됩니다. 이 시점부터 Mac에서 직접 작업하면 Windows와 파일을 주고받을 필요가 없습니다. 다른 사람이 올린 후속 변경은 로컬 작업을 보존한 뒤 `git pull --ff-only`로 받습니다. 충돌하거나 로컬 변경이 있으면 강제 초기화하지 말고 먼저 확인합니다.
