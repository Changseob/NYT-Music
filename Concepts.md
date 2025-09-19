# NYT-Music
[Youtube Music](https://music.youtube.com/)에 in-app browser 접속해서, javascript injection을 통하여 재생되는 음악의 속도, 구간 반복, 음악의 pitch(transpose)를 조절할 수 있도록하고, 각 음악의 url을 저장해서 플레이리스트를 관리할 수 있도록 하는 어플리케이션

## UI 설명
### 앱 실행 시
- Youtube Music으로 접속, 해당 사이트에 로그인 여부를 판별하여 로그인이 되어 있지 않다면 로그인 확인 팝업을 띄움
- 로그인 요청 시, Youtube Music Login 사이트로 접속하여, 사용자가 직접 in-app browser로 해당 사이트에 로그인 할 수 있도록하고, 해당 로그인 쿠키를 in-app browser에서 유지할 수 있도록 한다

### 앱 화면 구성
- 앱은 세로(portrait)를 기본으로 하고, 화면의 85%를 in-app browser가 차지하고 남은 15%에 대해서 앱에서 해당 사이트의 음악 재생을 컨트롤 할 수 있는 컨트롤 UI로 구성한다.
