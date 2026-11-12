# 로컬 가사 개발 서버

Python 3.10 이상으로 실행합니다. 외부 패키지는 필요 없습니다. 이 서버는 localhost에만 바인딩하는 개발용 HTTP 서버이며 운영 배포·사용자 인증·상용 공급자는 포함하지 않습니다.

```sh
python -m backend.app --port 8787
python -m unittest discover -s backend/tests -v
```

확인 주소:

- `http://localhost:8787/health`
- `http://localhost:8787/v1/lyrics?trackID=demo%3Aopen-road`

원본 데모 곡만 반환하며 다른 ID는 404입니다. Spotify 요청은 403입니다. 응답은 no-store이며 60초당 60회 제한과 입력 검증이 있습니다. 요청 URL·곡 ID·공급자 응답을 로그에 남기지 않습니다. 공급자는 providers.py의 프로토콜로 교체할 수 있습니다.

## iOS 시뮬레이터 연결

Mac에서 서버를 실행하고 Config/Local.xcconfig에 다음을 설정합니다. xcconfig에서 //가 주석으로 해석되지 않도록 빈 변수 표현을 사용합니다.

```xcconfig
LYRICS_API_URL = http:/$()/localhost:8787/v1/lyrics
```

Debug iOS 시뮬레이터에서 Demo를 선택하면 로컬 서버를 사용합니다. 서버를 종료한 뒤 가사 재시도로 연결 오류를 확인할 수 있습니다. 설정을 지우면 원래 로컬 모의 가사로 돌아갑니다. localhost HTTP는 Debug 시뮬레이터에서만 허용되며 기기·Release는 HTTPS를 요구합니다. iPhone에서 localhost는 Mac을 가리키지 않습니다.

실제 공급자 연결 전에는 [계약](../docs/backend-contract.md), 권리·국가·출처·보관 조건, 사용자 인증·쿼터·TLS·비밀 저장소·운영 HTTP 서버를 구성해야 합니다. 이 개발 서버를 외부 인터넷에 노출하지 않습니다.
