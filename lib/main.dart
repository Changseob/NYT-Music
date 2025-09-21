import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const NYTMusicApp());
}

class NYTMusicApp extends StatelessWidget {
  const NYTMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NYT Music',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _webViewController;
  bool _isLoggedIn = false;
  bool _isLoading = true;

  // Side menu state
  bool _isMenuOpen = false;

  // Music control states
  double _playbackSpeed = 1.0;
  double _pitch = 0.0; // transpose in semitones (+12 to -12)
  double? _startLoop = null; // A point for repeat
  double? _endLoop = null; // B point for repeat

  // Player states
  bool _isPlaying = false;
  double _currentTime = 0.0;
  double _duration = 0.0;
  String _currentTitle = '';
  String _currentArtist = '';
  bool _isAudioOnlyMode = true; // 기본적으로 오디오 전용 모드 활성화

  // Controllers for text editing
  final TextEditingController _speedController = TextEditingController();
  final TextEditingController _pitchController = TextEditingController();

  // Timer for updating player state
  Timer? _stateUpdateTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
    _speedController.text = '100%';
    _pitchController.text = '+0';
    _startStateUpdateTimer();
  }

  @override
  void dispose() {
    _stateUpdateTimer?.cancel();
    _speedController.dispose();
    _pitchController.dispose();
    super.dispose();
  }

  void _startStateUpdateTimer() {
    _stateUpdateTimer = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) {
      _updatePlayerState();
    });
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0x00000000))
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading progress if needed
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
            // 페이지 로드 시작 시에도 전체화면 차단 적용
            Future.delayed(const Duration(milliseconds: 500), () {
              _hideVideoElements();
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkLoginStatus();
            _hideVideoElements();
            _setupPlaybackEventListeners();
            // 추가로 2초 후에 한 번 더 적용하여 동적 로딩 요소들 처리
            Future.delayed(const Duration(seconds: 2), () {
              _hideVideoElements();
              _setupPlaybackEventListeners();
            });
            // 5초 후에 한 번 더 이벤트 리스너 설정 (동적 로딩 대응)
            Future.delayed(const Duration(seconds: 5), () {
              _setupPlaybackEventListeners();
            });
          },
          onWebResourceError: (WebResourceError error) {
            // Handle web resource errors
          },
        ),
      )
      ..loadRequest(Uri.parse('https://music.youtube.com/'));
  }

  void _checkLoginStatus() async {
    // JavaScript to check if user is logged in
    const String checkLoginScript = '''
      (function() {
        // Check for presence of user avatar or account elements
        const accountElement = document.querySelector('[aria-label*="계정"], [aria-label*="Account"], .ytmusic-nav-bar .right-content .ytmusic-player-bar');
        const avatarElement = document.querySelector('img[id*="avatar"], .style-scope.ytmusic-nav-bar img');
        return !!(accountElement || avatarElement);
      })();
    ''';

    try {
      final result = await _webViewController.runJavaScriptReturningResult(
        checkLoginScript,
      );
      setState(() {
        _isLoggedIn = result == true;
      });

      if (!_isLoggedIn) {
        _showLoginDialog();
      }
    } catch (e) {
      // Handle error
    }
  }

  void _showLoginDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('로그인 필요'),
          content: const Text(
            'YouTube Music을 사용하려면 로그인이 필요합니다. 로그인 페이지로 이동하시겠습니까?',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('취소'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('로그인'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToLogin();
              },
            ),
          ],
        );
      },
    );
  }

  void _navigateToLogin() {
    _webViewController.loadRequest(
      Uri.parse('https://accounts.google.com/signin'),
    );
  }

  void _setPlaybackSpeed(double speed) async {
    setState(() {
      _playbackSpeed = speed;
      _speedController.text = '${(speed * 100).toInt()}%';
    });

    final String script =
        '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          video.playbackRate = $speed;
        }
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (e) {
      // Handle error
    }
  }

  void _setPitch(double pitch) async {
    setState(() {
      _pitch = pitch;
      _pitchController.text = '${pitch >= 0 ? '+' : ''}${pitch.toInt()}';
    });

    // This would require more complex audio processing
    // For now, just store the value
  }

  void _resetSpeed() {
    _setPlaybackSpeed(1.0);
  }

  void _resetPitch() {
    _setPitch(0.0);
  }

  void _showSpeedEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String inputText = '${(_playbackSpeed * 100).toInt()}';
        return AlertDialog(
          title: const Text('박자 수정'),
          content: TextField(
            controller: TextEditingController(text: inputText),
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '박자 (%)',
              hintText: '50-200',
            ),
            onChanged: (value) => inputText = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final speed = double.tryParse(inputText);
                if (speed != null && speed >= 50 && speed <= 200) {
                  _setPlaybackSpeed(speed / 100);
                }
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _showPitchEditDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String inputText = '${_pitch.toInt()}';
        return AlertDialog(
          title: const Text('피치 수정'),
          content: TextField(
            controller: TextEditingController(text: inputText),
            keyboardType: TextInputType.numberWithOptions(signed: true),
            decoration: const InputDecoration(
              labelText: '피치',
              hintText: '-12 ~ +12',
            ),
            onChanged: (value) => inputText = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () {
                final pitch = double.tryParse(inputText);
                if (pitch != null && pitch >= -12 && pitch <= 12) {
                  _setPitch(pitch);
                }
                Navigator.of(context).pop();
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  void _setLoopPoint(String point) async {
    // Get current time from video
    const String script = '''
      (function() {
        const video = document.querySelector('video');
        return video ? video.currentTime : 0;
      })();
    ''';

    try {
      final result = await _webViewController.runJavaScriptReturningResult(
        script,
      );
      final currentTime = result as double;

      setState(() {
        if (point == 'A') {
          _startLoop = currentTime;
        } else if (point == 'B') {
          _endLoop = currentTime;
        }
      });

      // If both A and B are set, implement loop
      if (_startLoop != null && _endLoop != null) {
        _implementLoop();
      }
    } catch (e) {
      // Handle error
    }
  }

  void _clearLoop() {
    setState(() {
      _startLoop = null;
      _endLoop = null;
    });

    // Remove loop from video
    const String script = '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          video.loop = false;
          video.removeEventListener('timeupdate', window.loopHandler);
        }
      })();
    ''';

    _webViewController.runJavaScript(script);
  }

  void _implementLoop() async {
    if (_startLoop == null || _endLoop == null) return;

    final String script =
        '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          // Remove existing loop handler
          if (window.loopHandler) {
            video.removeEventListener('timeupdate', window.loopHandler);
          }
          
          // Create new loop handler
          window.loopHandler = function() {
            if (video.currentTime >= $_endLoop) {
              video.currentTime = $_startLoop;
            }
          };
          
          video.addEventListener('timeupdate', window.loopHandler);
        }
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (e) {
      // Handle error
    }
  }

  void _goHome() {
    _webViewController.loadRequest(Uri.parse('https://music.youtube.com/'));
  }

  void _toggleAudioOnlyMode() {
    setState(() {
      _isAudioOnlyMode = !_isAudioOnlyMode;
    });

    if (_isAudioOnlyMode) {
      _hideVideoElements();
    } else {
      _showVideoElements();
    }
  }

  void _showVideoElements() async {
    const String script = '''
      (function() {
        // 비디오 요소 다시 보이기
        const videos = document.querySelectorAll('video');
        videos.forEach(video => {
          video.style.display = '';
          video.style.visibility = '';
          video.style.opacity = '';
          video.style.width = '';
          video.style.height = '';
          video.style.position = '';
          video.style.left = '';
          video.style.top = '';
        });

        // 비디오 컨테이너들도 다시 보이기
        const videoContainers = document.querySelectorAll(
          '.video-stream, .video-container, .player-video-container, ' +
          '.ytmusic-player-video, .video, .player-video, ' +
          '.html5-video-container, .ytp-videoWrapper'
        );
        videoContainers.forEach(container => {
          container.style.display = '';
          container.style.visibility = '';
          container.style.opacity = '';
        });

        // YouTube Music 특정 비디오 관련 요소들 보이기
        const musicVideoElements = document.querySelectorAll(
          'ytmusic-player-video, .video-stream-wrapper, ' +
          '.ytmusic-watch-video-content, .video-content'
        );
        musicVideoElements.forEach(element => {
          element.style.display = '';
        });

        // 풀스크린 버튼 다시 보이기
        const fullscreenButtons = document.querySelectorAll(
          '.ytp-fullscreen-button, .fullscreen-button'
        );
        fullscreenButtons.forEach(button => {
          button.style.display = '';
        });

        // 주입된 CSS 스타일 제거
        const injectedStyles = document.querySelectorAll('style');
        injectedStyles.forEach(style => {
          if (style.textContent && style.textContent.includes('video,')) {
            style.remove();
          }
        });

        return 'Video elements shown successfully';
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      print('비디오 요소 표시 처리 완료');
    } catch (e) {
      print('비디오 표시 처리 오류: \$e');
    }
  }

  void _setupPlaybackEventListeners() async {
    const String script = '''
      (function() {
        // 재생 상태 변화 감지를 위한 이벤트 리스너 설정
        function setupEventListeners() {
          const video = document.querySelector('video');
          if (video) {
            // 기존 리스너 제거 (중복 방지)
            video.removeEventListener('play', window.flutterPlayListener);
            video.removeEventListener('pause', window.flutterPauseListener);
            video.removeEventListener('timeupdate', window.flutterTimeUpdateListener);
            video.removeEventListener('loadedmetadata', window.flutterMetadataListener);
            video.removeEventListener('durationchange', window.flutterDurationListener);
            
            // 상태 변화를 저장할 전역 변수
            window.lastPlayState = !video.paused;
            window.lastCurrentTime = video.currentTime || 0;
            window.lastDuration = video.duration || 0;
            
            // 새 리스너 추가 (상태를 전역 변수에 저장)
            window.flutterPlayListener = function() {
              console.log('Video play event detected');
              window.lastPlayState = true;
            };
            
            window.flutterPauseListener = function() {
              console.log('Video pause event detected');
              window.lastPlayState = false;
            };
            
            window.flutterTimeUpdateListener = function() {
              window.lastCurrentTime = video.currentTime || 0;
              window.lastDuration = video.duration || 0;
            };
            
            window.flutterMetadataListener = function() {
              console.log('Video metadata loaded');
              window.lastDuration = video.duration || 0;
            };
            
            window.flutterDurationListener = function() {
              console.log('Video duration changed');
              window.lastDuration = video.duration || 0;
            };
            
            video.addEventListener('play', window.flutterPlayListener);
            video.addEventListener('pause', window.flutterPauseListener);
            video.addEventListener('timeupdate', window.flutterTimeUpdateListener);
            video.addEventListener('loadedmetadata', window.flutterMetadataListener);
            video.addEventListener('durationchange', window.flutterDurationListener);
            
            return 'Event listeners setup complete';
          }
          return 'No video element found';
        }
        
        return setupEventListeners();
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      print('재생 이벤트 리스너 설정 완료');
    } catch (e) {
      print('이벤트 리스너 설정 오류: \$e');
    }
  }

  void _hideVideoElements() async {
    if (!_isAudioOnlyMode) return; // 오디오 전용 모드가 아니면 실행하지 않음

    const String script = '''
      (function() {
        // 전체화면 모드 완전 차단 및 비디오 요소 숨기기
        function blockFullscreenAndHideVideo() {
          // 1. 전체화면 API 차단
          if (document.documentElement.requestFullscreen) {
            document.documentElement.requestFullscreen = function() { 
              console.log('Fullscreen blocked'); 
              return Promise.reject(new Error('Fullscreen blocked')); 
            };
          }
          if (document.documentElement.webkitRequestFullscreen) {
            document.documentElement.webkitRequestFullscreen = function() { 
              console.log('Webkit Fullscreen blocked'); 
              return Promise.reject(new Error('Fullscreen blocked')); 
            };
          }
          if (document.documentElement.mozRequestFullScreen) {
            document.documentElement.mozRequestFullScreen = function() { 
              console.log('Moz Fullscreen blocked'); 
              return Promise.reject(new Error('Fullscreen blocked')); 
            };
          }

          // 2. 전체화면 이벤트 차단
          document.addEventListener('fullscreenchange', function(e) {
            if (document.fullscreenElement) {
              document.exitFullscreen();
            }
            e.stopPropagation();
            e.preventDefault();
          }, true);
          
          document.addEventListener('webkitfullscreenchange', function(e) {
            if (document.webkitFullscreenElement) {
              document.webkitExitFullscreen();
            }
            e.stopPropagation();
            e.preventDefault();
          }, true);

          // 3. YouTube Music 전체화면 모드 차단
          const blockFullscreenElements = () => {
            // 전체화면 오버레이 차단
            const fullscreenOverlays = document.querySelectorAll(
              '.video-stream-overlay, .fullscreen-overlay, .theater-mode, ' +
              '.ytmusic-fullscreen, .ytp-fullscreen, .fullscreen-video, ' +
              '.video-fullscreen, .watch-video-fullscreen, .cinema-mode'
            );
            fullscreenOverlays.forEach(overlay => {
              overlay.style.display = 'none !important';
              overlay.style.visibility = 'hidden !important';
              overlay.style.opacity = '0 !important';
              overlay.style.zIndex = '-1 !important';
              overlay.style.position = 'absolute !important';
              overlay.style.left = '-9999px !important';
              overlay.style.top = '-9999px !important';
            });

            // 검은색 배경 제거
            const blackOverlays = document.querySelectorAll(
              '[style*="background"], [style*="black"], .video-background, ' +
              '.player-background, .dark-overlay'
            );
            blackOverlays.forEach(overlay => {
              if (overlay.style.backgroundColor === 'black' || 
                  overlay.style.background === 'black' ||
                  overlay.style.backgroundColor === 'rgb(0, 0, 0)') {
                overlay.style.display = 'none !important';
              }
            });
          };

          // 4. 비디오 요소 숨기기
          const hideVideoElements = () => {
            const videos = document.querySelectorAll('video');
            videos.forEach(video => {
              video.style.display = 'none !important';
              video.style.visibility = 'hidden !important';
              video.style.opacity = '0 !important';
              video.style.width = '0px !important';
              video.style.height = '0px !important';
              video.style.position = 'absolute !important';
              video.style.left = '-9999px !important';
              video.style.top = '-9999px !important';
              video.style.zIndex = '-1 !important';
              
              // 오디오 전용 설정
              video.setAttribute('playsinline', 'true');
              video.setAttribute('webkit-playsinline', 'true');
              video.muted = false;
              
              // 전체화면 관련 이벤트 차단
              video.addEventListener('webkitbeginfullscreen', function(e) {
                e.preventDefault();
                e.stopPropagation();
              }, true);
              
              video.addEventListener('webkitendfullscreen', function(e) {
                e.preventDefault();
                e.stopPropagation();
              }, true);
            });

            // 비디오 컨테이너들 숨기기
            const videoContainers = document.querySelectorAll(
              '.video-stream, .video-container, .player-video-container, ' +
              '.ytmusic-player-video, .video, .player-video, ' +
              '.html5-video-container, .ytp-videoWrapper, .video-wrapper, ' +
              '.player-wrapper, .video-player-container, .watch-video-container'
            );
            videoContainers.forEach(container => {
              container.style.display = 'none !important';
              container.style.visibility = 'hidden !important';
              container.style.opacity = '0 !important';
              container.style.zIndex = '-1 !important';
            });

            // YouTube Music 특정 요소들 숨기기
            const musicVideoElements = document.querySelectorAll(
              'ytmusic-player-video, .video-stream-wrapper, ' +
              '.ytmusic-watch-video-content, .video-content, ' +
              '.watch-video, .video-primary-content'
            );
            musicVideoElements.forEach(element => {
              element.style.display = 'none !important';
              element.style.visibility = 'hidden !important';
              element.style.opacity = '0 !important';
            });
          };

          // 5. 전체화면 버튼 숨기기 및 클릭 이벤트 차단
          const blockFullscreenButtons = () => {
            const fullscreenButtons = document.querySelectorAll(
              '.ytp-fullscreen-button, .fullscreen-button, ' +
              '[aria-label*="전체"], [aria-label*="Fullscreen"], ' +
              '[aria-label*="극장"], [aria-label*="Theater"]'
            );
            fullscreenButtons.forEach(button => {
              button.style.display = 'none !important';
              button.style.visibility = 'hidden !important';
              button.style.pointerEvents = 'none !important';
              
              // 클릭 이벤트 차단
              button.addEventListener('click', function(e) {
                e.preventDefault();
                e.stopPropagation();
                e.stopImmediatePropagation();
              }, true);
            });
          };

          // 즉시 실행
          blockFullscreenElements();
          hideVideoElements();
          blockFullscreenButtons();

          // 6. 주기적으로 재적용 (강제)
          setInterval(() => {
            blockFullscreenElements();
            hideVideoElements();
            blockFullscreenButtons();
          }, 1000);
        }

        // 즉시 실행
        blockFullscreenAndHideVideo();

        // DOM 변경 감지
        const observer = new MutationObserver(function(mutations) {
          mutations.forEach(function(mutation) {
            if (mutation.addedNodes) {
              mutation.addedNodes.forEach(function(node) {
                if (node.nodeType === 1) {
                  // 새로 추가된 비디오 요소 처리
                  const newVideos = node.querySelectorAll ? node.querySelectorAll('video') : [];
                  newVideos.forEach(video => {
                    video.style.display = 'none !important';
                    video.style.visibility = 'hidden !important';
                    video.style.opacity = '0 !important';
                    video.style.zIndex = '-1 !important';
                  });

                  // 전체화면 오버레이 차단
                  if (node.classList && (
                    node.classList.contains('video-stream-overlay') ||
                    node.classList.contains('fullscreen-overlay') ||
                    node.classList.contains('ytmusic-fullscreen')
                  )) {
                    node.style.display = 'none !important';
                  }
                }
              });
            }
          });
        });

        observer.observe(document.body, {
          childList: true,
          subtree: true
        });

        // CSS 스타일 주입
        const style = document.createElement('style');
        style.textContent = `
          video, 
          .video-stream, 
          .video-container, 
          .player-video-container,
          .ytmusic-player-video,
          .html5-video-container,
          .ytp-videoWrapper,
          ytmusic-player-video,
          .video-wrapper,
          .player-wrapper,
          .video-player-container,
          .watch-video-container,
          .video-stream-overlay,
          .fullscreen-overlay,
          .theater-mode,
          .ytmusic-fullscreen,
          .ytp-fullscreen,
          .fullscreen-video,
          .video-fullscreen,
          .watch-video-fullscreen,
          .cinema-mode {
            display: none !important;
            visibility: hidden !important;
            opacity: 0 !important;
            width: 0 !important;
            height: 0 !important;
            position: absolute !important;
            left: -9999px !important;
            top: -9999px !important;
            z-index: -1 !important;
          }
          
          .ytp-fullscreen-button,
          .fullscreen-button,
          [aria-label*="전체"],
          [aria-label*="Fullscreen"],
          [aria-label*="극장"],
          [aria-label*="Theater"] {
            display: none !important;
            visibility: hidden !important;
            pointer-events: none !important;
          }
          
          /* 검은색 배경 강제 제거 */
          [style*="background: black"],
          [style*="background-color: black"],
          [style*="background: rgb(0, 0, 0)"],
          [style*="background-color: rgb(0, 0, 0)"] {
            background: transparent !important;
            background-color: transparent !important;
          }
        `;
        document.head.appendChild(style);

        return 'Fullscreen blocked and video elements hidden successfully';
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      print('전체화면 차단 및 비디오 요소 숨김 처리 완료');
    } catch (e) {
      print('전체화면 차단 처리 오류: \$e');
    }
  }

  void _updatePlayerState() async {
    const String script = '''
      (function() {
        const video = document.querySelector('video');
        
        // 다양한 방법으로 제목과 아티스트 정보 찾기
        let titleElement = document.querySelector('.title.style-scope.ytmusic-player-bar') ||
                          document.querySelector('ytmusic-player-bar .title') ||
                          document.querySelector('.ytmusic-player-bar .content-info-wrapper .title') ||
                          document.querySelector('[class*="title"]') ||
                          document.querySelector('h1') ||
                          document.querySelector('.song-title');
                          
        let artistElement = document.querySelector('.byline.style-scope.ytmusic-player-bar') ||
                           document.querySelector('ytmusic-player-bar .byline') ||
                           document.querySelector('.ytmusic-player-bar .content-info-wrapper .byline') ||
                           document.querySelector('[class*="byline"]') ||
                           document.querySelector('.artist-name');
        
        // 재생 버튼 상태도 확인
        let playButton = document.querySelector('tp-yt-paper-icon-button[aria-label*="재생"], tp-yt-paper-icon-button[aria-label*="Play"], tp-yt-paper-icon-button[aria-label*="일시정지"], tp-yt-paper-icon-button[aria-label*="Pause"]');
        let isPlayingFromButton = false;
        if (playButton) {
          let ariaLabel = playButton.getAttribute('aria-label') || '';
          isPlayingFromButton = ariaLabel.includes('일시정지') || ariaLabel.includes('Pause');
        }
        
        // 오디오 전용 모드일 때 비디오 요소 숨김 유지
        if (video && video.style.display !== 'none') {
          video.style.display = 'none !important';
          video.style.visibility = 'hidden !important';
          video.style.opacity = '0 !important';
          video.style.zIndex = '-1 !important';
        }
        
        // 전체화면 모드 차단
        if (document.fullscreenElement || document.webkitFullscreenElement) {
          try {
            if (document.exitFullscreen) document.exitFullscreen();
            if (document.webkitExitFullscreen) document.webkitExitFullscreen();
          } catch (e) {
            console.log('Fullscreen exit error:', e);
          }
        }
        
        if (video) {
          // 이벤트 리스너에서 저장된 상태 우선 사용
          let eventBasedPlayState = window.lastPlayState !== undefined ? window.lastPlayState : (!video.paused && !video.ended);
          let eventBasedCurrentTime = window.lastCurrentTime !== undefined ? window.lastCurrentTime : video.currentTime;
          let eventBasedDuration = window.lastDuration !== undefined ? window.lastDuration : video.duration;
          
          // 비디오, 이벤트, 버튼 상태를 모두 고려하여 최종 재생 상태 결정
          let videoPlaying = !video.paused && !video.ended;
          let finalPlayingState = eventBasedPlayState || videoPlaying || isPlayingFromButton;
          
          return {
            isPlaying: finalPlayingState,
            currentTime: eventBasedCurrentTime || 0,
            duration: eventBasedDuration || 0,
            title: titleElement ? titleElement.textContent.trim() : '',
            artist: artistElement ? artistElement.textContent.trim() : '',
            videoExists: true,
            eventListenerActive: window.lastPlayState !== undefined
          };
        }
        
        // 비디오가 없을 때도 버튼 상태로 재생 정보 제공
        return {
          isPlaying: isPlayingFromButton,
          currentTime: 0,
          duration: 0,
          title: titleElement ? titleElement.textContent.trim() : '',
          artist: artistElement ? artistElement.textContent.trim() : '',
          videoExists: false,
          eventListenerActive: false
        };
      })();
    ''';

    try {
      final result = await _webViewController.runJavaScriptReturningResult(
        script,
      );
      if (result is Map) {
        // 상태가 실제로 변경되었을 때만 setState 호출
        bool hasChanges = false;

        bool newIsPlaying = result['isPlaying'] ?? false;
        double newCurrentTime = (result['currentTime'] ?? 0.0).toDouble();
        double newDuration = (result['duration'] ?? 0.0).toDouble();
        String newTitle = (result['title'] ?? '').toString();
        String newArtist = (result['artist'] ?? '').toString();

        if (_isPlaying != newIsPlaying ||
            (_currentTime - newCurrentTime).abs() > 0.5 ||
            (_duration - newDuration).abs() > 0.5 ||
            _currentTitle != newTitle ||
            _currentArtist != newArtist) {
          hasChanges = true;
        }

        if (hasChanges) {
          setState(() {
            _isPlaying = newIsPlaying;
            _currentTime = newCurrentTime;
            _duration = newDuration;
            _currentTitle = newTitle;
            _currentArtist = newArtist;
          });
        }
      }

      // 10초마다 전체화면 차단 재적용 (부하 줄이기)
      if (_isAudioOnlyMode && DateTime.now().second % 10 == 0) {
        _hideVideoElements();
      }
    } catch (e) {
      // Handle error silently to avoid spam
    }
  }

  void _playPause() async {
    const String script = '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          if (video.paused) {
            video.play();
          } else {
            video.pause();
          }
          
          // 재생 시에도 비디오 요소 숨김 확실히 처리
          video.style.display = 'none !important';
          video.style.visibility = 'hidden !important';
          video.style.opacity = '0 !important';
          video.style.width = '0px !important';
          video.style.height = '0px !important';
          video.style.position = 'absolute !important';
          video.style.left = '-9999px !important';
          video.style.top = '-9999px !important';
          video.style.zIndex = '-1 !important';
          video.muted = false; // 오디오는 재생되도록
          
          // 전체화면 모드 즉시 해제
          if (document.fullscreenElement) {
            document.exitFullscreen();
          }
          if (document.webkitFullscreenElement) {
            document.webkitExitFullscreen();
          }
        }
        
        // 즉시 전체화면 오버레이 제거
        const overlays = document.querySelectorAll('.video-stream-overlay, .fullscreen-overlay, .ytmusic-fullscreen');
        overlays.forEach(overlay => {
          overlay.style.display = 'none !important';
          overlay.style.visibility = 'hidden !important';
          overlay.style.zIndex = '-1 !important';
        });
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      // 재생/일시정지 후 처리
      if (_isAudioOnlyMode) {
        Future.delayed(const Duration(milliseconds: 200), () {
          _hideVideoElements();
        });
        Future.delayed(const Duration(milliseconds: 800), () {
          _hideVideoElements();
        });
      }
      // 이벤트 리스너 재설정하여 상태 동기화 개선
      Future.delayed(const Duration(milliseconds: 500), () {
        _setupPlaybackEventListeners();
      });
    } catch (e) {
      // Handle error
    }
  }

  void _previousTrack() async {
    const String script = '''
      (function() {
        const prevButton = document.querySelector('tp-yt-paper-icon-button[aria-label*="이전"], tp-yt-paper-icon-button[aria-label*="Previous"]');
        if (prevButton) {
          prevButton.click();
        }
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      // 곡 변경 후 처리
      if (_isAudioOnlyMode) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _hideVideoElements();
        });
      }
      // 새로운 곡에 대해 이벤트 리스너 재설정
      Future.delayed(const Duration(milliseconds: 2000), () {
        _setupPlaybackEventListeners();
      });
    } catch (e) {
      // Handle error
    }
  }

  void _nextTrack() async {
    const String script = '''
      (function() {
        const nextButton = document.querySelector('tp-yt-paper-icon-button[aria-label*="다음"], tp-yt-paper-icon-button[aria-label*="Next"]');
        if (nextButton) {
          nextButton.click();
        }
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
      // 곡 변경 후 처리
      if (_isAudioOnlyMode) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          _hideVideoElements();
        });
      }
      // 새로운 곡에 대해 이벤트 리스너 재설정
      Future.delayed(const Duration(milliseconds: 2000), () {
        _setupPlaybackEventListeners();
      });
    } catch (e) {
      // Handle error
    }
  }

  void _seekTo(double position) async {
    final String script =
        '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          video.currentTime = $position;
        }
      })();
    ''';

    try {
      await _webViewController.runJavaScript(script);
    } catch (e) {
      // Handle error
    }
  }

  Widget _buildSideMenu() {
    return Container(
      width: 250,
      height: double.infinity,
      color: Colors.white,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.red,
            width: double.infinity,
            child: const Text(
              'NYT Music',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // 오디오 전용 모드 토글
          SwitchListTile(
            secondary: Icon(
              _isAudioOnlyMode ? Icons.music_note : Icons.videocam,
              color: _isAudioOnlyMode ? Colors.green : Colors.blue,
            ),
            title: const Text('오디오 전용 모드'),
            subtitle: Text(
              _isAudioOnlyMode ? '비디오 숨김' : '비디오 표시',
              style: const TextStyle(fontSize: 12),
            ),
            value: _isAudioOnlyMode,
            onChanged: (bool value) {
              _toggleAudioOnlyMode();
            },
          ),

          const Divider(),

          ListTile(
            leading: const Icon(Icons.playlist_play),
            title: const Text('플레이리스트'),
            onTap: () {
              setState(() => _isMenuOpen = false);
              // TODO: Navigate to playlist
            },
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () {
              setState(() => _isMenuOpen = false);
              // TODO: Navigate to settings
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('앱 정보'),
            onTap: () {
              setState(() => _isMenuOpen = false);
              // TODO: Show app info
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // WebView takes 60% of screen height
                Expanded(
                  flex: 60,
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _webViewController),
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),

                // Control UI takes 40% of screen height
                Expanded(
                  flex: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      border: const Border(
                        top: BorderSide(color: Colors.grey, width: 0.5),
                      ),
                    ),
                    child: _buildControlPanel(),
                  ),
                ),
              ],
            ),

            // Side menu overlay
            if (_isMenuOpen)
              GestureDetector(
                onTap: () => setState(() => _isMenuOpen = false),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _buildSideMenu(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Column(
        children: [
          // Song Info Section
          if (_currentTitle.isNotEmpty)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Text(
                    _currentTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_currentArtist.isNotEmpty)
                    Text(
                      _currentArtist,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),

          // Progress Bar Section with A/B markers
          Expanded(
            flex: 1,
            child: Column(
              children: [
                // Progress Bar with A/B markers
                SizedBox(
                  height: 30,
                  child: Stack(
                    children: [
                      // Main progress bar
                      Positioned.fill(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _duration > 0 ? _currentTime : 0,
                            min: 0,
                            max: _duration > 0 ? _duration : 1,
                            onChanged: (value) => _seekTo(value),
                          ),
                        ),
                      ),
                      // A marker
                      if (_startLoop != null && _duration > 0)
                        Positioned(
                          left:
                              (_startLoop! / _duration) *
                                  (MediaQuery.of(context).size.width - 24) -
                              8,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'A',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // B marker
                      if (_endLoop != null && _duration > 0)
                        Positioned(
                          left:
                              (_endLoop! / _duration) *
                                  (MediaQuery.of(context).size.width - 24) -
                              8,
                          top: 0,
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Text(
                                'B',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatTime(_currentTime),
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      _formatTime(_duration),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Player Controls Section
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _previousTrack(),
                  icon: const Icon(Icons.skip_previous, size: 24),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _playPause(),
                  icon: Icon(
                    _isPlaying ? Icons.pause_circle : Icons.play_circle,
                    size: 48,
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () => _nextTrack(),
                  icon: const Icon(Icons.skip_next, size: 24),
                ),
              ],
            ),
          ),

          // Speed Control Section (박자 조절)
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.speed, size: 16),
                const SizedBox(width: 4),
                const Text('박자', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _playbackSpeed,
                    min: 0.5,
                    max: 2.0,
                    divisions: 30,
                    onChanged: _setPlaybackSpeed,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSpeedEditDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${(_playbackSpeed * 100).toInt()}%',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _resetSpeed(),
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),

          // Pitch Control Section (피치 조절)
          Expanded(
            flex: 1,
            child: Row(
              children: [
                const Icon(Icons.music_note, size: 16),
                const SizedBox(width: 4),
                const Text('피치', style: TextStyle(fontSize: 10)),
                const SizedBox(width: 8),
                Expanded(
                  child: Slider(
                    value: _pitch,
                    min: -12.0,
                    max: 12.0,
                    divisions: 24,
                    onChanged: _setPitch,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPitchEditDialog(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${_pitch >= 0 ? '+' : ''}${_pitch.toInt()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _resetPitch(),
                  icon: const Icon(Icons.refresh, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Row: A/B Repeat and Navigation
          Expanded(
            flex: 1,
            child: Row(
              children: [
                // Left side: A/B Repeat controls
                Expanded(
                  child: Row(
                    children: [
                      ElevatedButton(
                        onPressed: () => _setLoopPoint('A'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _startLoop != null
                              ? Colors.green
                              : null,
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('A', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      ElevatedButton(
                        onPressed: () => _setLoopPoint('B'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _endLoop != null ? Colors.red : null,
                          minimumSize: const Size(32, 32),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                        child: const Text('B', style: TextStyle(fontSize: 12)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        onPressed: () => _clearLoop(),
                        icon: const Icon(Icons.delete, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right side: Home and Menu buttons
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: () => _goHome(),
                        icon: const Icon(Icons.home, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () => setState(() => _isMenuOpen = true),
                        icon: const Icon(Icons.menu, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 40,
                          minHeight: 40,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(double seconds) {
    final int minutes = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
