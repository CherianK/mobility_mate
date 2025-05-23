import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../utils/pattern_painters.dart';

class VideoPlayerScreen extends StatefulWidget {
  const VideoPlayerScreen({super.key});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late final WebViewController _controller;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    // Lock to portrait mode initially
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String url) {
            // Enable fullscreen mode when page is loaded
            _controller.runJavaScript('''
              document.querySelector('iframe').style.width = '100%';
              document.querySelector('iframe').style.height = '100%';
              document.querySelector('iframe').style.position = 'fixed';
              document.querySelector('iframe').style.top = '0';
              document.querySelector('iframe').style.left = '0';
              document.querySelector('iframe').style.border = 'none';

              // Listen for fullscreen changes
              document.addEventListener('fullscreenchange', function() {
                window.flutter_inappwebview.callHandler('onFullscreenChange', document.fullscreenElement !== null);
              });
            ''');
          },
        ),
      )
      ..addJavaScriptChannel(
        'flutter_inappwebview',
        onMessageReceived: (JavaScriptMessage message) {
          if (message.message == 'true') {
            // Enter fullscreen
            setState(() => _isFullScreen = true);
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
              DeviceOrientation.landscapeLeft,
              DeviceOrientation.landscapeRight,
            ]);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
          } else {
            // Exit fullscreen
            setState(() => _isFullScreen = false);
            SystemChrome.setPreferredOrientations([
              DeviceOrientation.portraitUp,
            ]);
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
          }
        },
      )
      ..loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head>
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <style>
            body {
              margin: 0;
              padding: 0;
              background: black;
              display: flex;
              justify-content: center;
              align-items: center;
              height: 100vh;
            }
            iframe {
              width: 100%;
              height: 100%;
              border: none;
            }
          </style>
        </head>
        <body>
          <iframe
            src="https://www.youtube.com/embed/rA--CehFBSY?autoplay=1&playsinline=1&enablejsapi=1&modestbranding=1&rel=0&showinfo=0&controls=0&iv_load_policy=3&fs=1&color=white"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen
          ></iframe>
        </body>
        </html>
      ''');
  }

  @override
  void dispose() {
    // Reset orientation and system UI when leaving the screen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDarkMode;
    final size = MediaQuery.of(context).size;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.grey[900] : Colors.grey[50],
      body: Column(
        children: [
          // Blue header
          if (!_isFullScreen)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: Colors.blue,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Back button
                        Container(
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                            tooltip: 'Back',
                            iconSize: 22,
                            padding: const EdgeInsets.all(8),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Product Video',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Add a SizedBox with the same width as the back button to balance the layout
                        const SizedBox(width: 44),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          // Main content
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[900] : Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // Video Player Container
                  Expanded(
                    child: Container(
                      margin: _isFullScreen ? EdgeInsets.zero : const EdgeInsets.all(16),
                      decoration: _isFullScreen ? null : BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: _isFullScreen ? BorderRadius.zero : BorderRadius.circular(16),
                        child: WebViewWidget(controller: _controller),
                      ),
                    ),
                  ),
                  
                  // Video Description (only show when not in fullscreen)
                  if (!_isFullScreen)
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'About Mobility Mate',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.blue.shade900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Watch our product video to see how Mobility Mate transforms the experience of people with mobility needs.',
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.5,
                              color: isDark ? Colors.grey[300] : Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 