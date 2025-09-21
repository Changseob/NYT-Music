# NYT-Music 구현 상세

## 개요
Concepts.md의 요구사항에 따라 YouTube Music을 in-app browser로 접속하여 음악 재생을 제어할 수 있는 Flutter 앱을 구현했습니다.

## 구현된 기능

### 1. 기본 UI 구조
- **화면 비율**: 세로(portrait) 모드 기본
- **WebView**: 화면의 85% 차지
- **컨트롤 UI**: 하단 15% 차지

### 2. WebView 설정
- **패키지**: `webview_flutter: ^4.4.2`
- **JavaScript 활성화**: `JavaScriptMode.unrestricted`
- **기본 URL**: `https://music.youtube.com/`
- **로딩 상태 표시**: CircularProgressIndicator

### 3. 로그인 감지 및 처리
- **로그인 확인**: JavaScript injection으로 계정 요소 확인
- **로그인 팝업**: 미로그인 시 확인 다이얼로그 표시
- **로그인 리다이렉트**: Google 계정 로그인 페이지로 이동

### 4. 음악 컨트롤 기능
- **재생 속도 조절**: 0.5x ~ 2.0x (슬라이더)
- **구간 반복**: 토글 버튼 (video.loop 제어)
- **음조(피치) 조절**: -12 ~ +12 세미톤 (슬라이더)

### 5. JavaScript Injection
- **속도 제어**: `video.playbackRate` 조작
- **반복 제어**: `video.loop` 조작
- **로그인 감지**: DOM 요소 검색

## 파일 구조
```
lib/
├── main.dart          # 메인 앱 및 UI 구현
design/
├── implementation.md  # 이 파일 - 구현 상세 문서
```

## 사용된 의존성
```yaml
dependencies:
  webview_flutter: ^4.4.2  # WebView 구현
  cookie_jar: ^4.0.8       # 쿠키 관리 (향후 사용)
  http: ^1.1.0             # HTTP 요청 (향후 사용)
```

## 향후 개발 예정 기능
1. **플레이리스트 관리**: URL 저장 및 관리
2. **고급 피치 제어**: Web Audio API 활용
3. **구간 반복**: A-B 구간 설정
4. **쿠키 지속성**: 로그인 상태 유지
