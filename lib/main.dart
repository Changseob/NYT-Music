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

  // Music control states
  double _playbackSpeed = 1.0;
  bool _isRepeating = false;
  double _pitch = 0.0; // transpose in semitones

  @override
  void initState() {
    super.initState();
    _initializeWebView();
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
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
            _checkLoginStatus();
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

  void _toggleRepeat() async {
    setState(() {
      _isRepeating = !_isRepeating;
    });

    // Implement repeat functionality through JavaScript
    final String script =
        '''
      (function() {
        const video = document.querySelector('video');
        if (video) {
          video.loop = $_isRepeating;
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
    });

    // This would require more complex audio processing
    // For now, just store the value
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // WebView takes 85% of screen height
            Expanded(
              flex: 85,
              child: Stack(
                children: [
                  WebViewWidget(controller: _webViewController),
                  if (_isLoading)
                    const Center(child: CircularProgressIndicator()),
                ],
              ),
            ),

            // Control UI takes 15% of screen height
            Expanded(
              flex: 15,
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
      ),
    );
  }

  Widget _buildControlPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        children: [
          // Speed Control
          Row(
            children: [
              const Icon(Icons.speed, size: 20),
              const SizedBox(width: 8),
              const Text('속도: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _playbackSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  label: '${_playbackSpeed.toStringAsFixed(1)}x',
                  onChanged: _setPlaybackSpeed,
                ),
              ),
            ],
          ),

          // Repeat and Pitch Controls
          Row(
            children: [
              // Repeat Button
              IconButton(
                onPressed: _toggleRepeat,
                icon: Icon(
                  Icons.repeat,
                  color: _isRepeating ? Colors.blue : Colors.grey,
                  size: 20,
                ),
              ),

              const SizedBox(width: 16),

              // Pitch Control
              const Icon(Icons.music_note, size: 20),
              const SizedBox(width: 8),
              const Text('음조: ', style: TextStyle(fontSize: 12)),
              Expanded(
                child: Slider(
                  value: _pitch,
                  min: -12.0,
                  max: 12.0,
                  divisions: 24,
                  label: '${_pitch.toStringAsFixed(0)}',
                  onChanged: _setPitch,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
