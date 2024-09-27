import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:open_settings_plus/core/open_settings_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool hideFooter = true; // Control footer visibility

  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;

  InAppWebViewSettings settings = InAppWebViewSettings(
    // isInspectable: kDebugMode,
    mediaPlaybackRequiresUserGesture: false,
    allowsInlineMediaPlayback: true,
    iframeAllow: "camera; microphone",
    iframeAllowFullscreen: true,
    cacheEnabled: true,
  );

  PullToRefreshController? pullToRefreshController;
  double progress = 0;
  bool isOffline = false; // Track internet status

  // Index to track the current tab selected
  int _currentIndex = 0;
  final List<String> _tabs = [
    'https://petelementsbd.com',
    'https://petelementsbd.com/flash-sale',
    'https://petelementsbd.com/shop',
    'https://petelementsbd.com/cart',
    'https://petelementsbd.com/blog',
  ];

  @override
  void initState() {
    super.initState();
    // Initial check
    checkInternetConnection();

    // Listener for connectivity changes
    Connectivity().onConnectivityChanged.listen((connectivityResult) {
      checkInternetConnection();
      if (connectivityResult != ConnectivityResult.none && !isOffline) {
        webViewController?.reload(); // Reload when back online
      }
    });

    pullToRefreshController = PullToRefreshController(
      settings: PullToRefreshSettings(color: Colors.blue),
      onRefresh: () async {
        await checkInternetConnection(); // Check connection during pull to refresh
        if (!isOffline) {
          webViewController?.reload(); // Reload content if back online
        }
        pullToRefreshController?.endRefreshing();
      },
    );
  }

  // Function to check the internet connection
  Future<void> checkInternetConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();

    // If connected to any network, check if there's actual internet access
    if (connectivityResult != ConnectivityResult.none) {
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          setState(() {
            isOffline = false; // Internet is available
          });
        }
      } on SocketException catch (_) {
        setState(() {
          isOffline = true; // No internet despite network connection
        });
      }
    } else {
      setState(() {
        isOffline = true; // No network connection at all
      });
    }
  }

  // Handle bottom navigation tab changes
  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (!isOffline) {
      webViewController?.loadUrl(
        urlRequest: URLRequest(url: WebUri(_tabs[index])),
      );
    }
  }

  // JavaScript to hide or show footer based on the condition
  String get footerScript {
    return hideFooter
        ? "document.getElementById('footer').style.display = 'none';"
        : "document.getElementById('footer').style.display = 'block';";
  }

  Future<bool?> _showBackDialog() {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: const Text(
            'Are you sure you want to leave this page?',
          ),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Never mind'),
              onPressed: () {
                Navigator.pop(context, false);
              },
            ),
            TextButton(
              style: TextButton.styleFrom(
                textStyle: Theme.of(context).textTheme.labelLarge,
              ),
              child: const Text('Leave'),
              onPressed: () {
                Navigator.pop(context, true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PopScope<Object?>(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, Object? result) async {
          if (didPop) {
            return;
          }
          // Check if WebView can go back
          if (await webViewController!.canGoBack()) {
            webViewController!.goBack();
          } else {
            // If WebView can't go back, show the dialog
            final bool shouldPop = await _showBackDialog() ?? false;
            if (context.mounted && shouldPop) {
              Navigator.pop(context);
            }
          }
        },
        child: SafeArea(
          child: isOffline
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cloud_off,
                          size: 100, color: Colors.grey),
                      const SizedBox(height: 20),
                      const Text(
                        "No Internet Connection",
                        style: TextStyle(fontSize: 20, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: () async {
                          await checkInternetConnection(); // Recheck the connection
                          if (!isOffline) {
                            webViewController
                                ?.reload(); // Reload if back online
                          } else {
                            // Show a SnackBar with an error message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    "No internet connection. Please check your network settings."),
                                action: SnackBarAction(
                                  label: 'Open Settings',
                                  onPressed: () async {
                                    switch (OpenSettingsPlus.shared) {
                                      case OpenSettingsPlusAndroid settings:
                                        settings.wifi();
                                      case OpenSettingsPlusIOS settings:
                                        settings.wifi();
                                    }
                                  },
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text("Try Again"),
                      ),
                    ],
                  ),
                )

              //
              : Stack(
                  children: [
                    //
                    InAppWebView(
                      key: webViewKey,
                      initialUrlRequest:
                          URLRequest(url: WebUri(_tabs[_currentIndex])),
                      initialSettings: settings,
                      pullToRefreshController: pullToRefreshController,
                      onWebViewCreated: (controller) {
                        webViewController = controller;
                      },
                      onPermissionRequest: (controller, request) async {
                        return PermissionResponse(
                          resources: request.resources,
                          action: PermissionResponseAction.GRANT,
                        );
                      },
                      onLoadStart: (controller, url) async {
                        setState(() {
                          progress = 0;
                        });
                        await controller.evaluateJavascript(
                            source: footerScript);
                      },
                      onLoadStop: (controller, url) async {
                        await controller.evaluateJavascript(
                            source: footerScript);
                        pullToRefreshController?.endRefreshing();
                        setState(() {
                          progress = 1.0;
                        });
                      },
                      shouldOverrideUrlLoading:
                          (controller, navigationAction) async {
                        final uri = navigationAction.request.url!;

                        // Check if the link is external (e.g.,tel, mailto)
                        if (uri.scheme == "tel" || uri.scheme == "mailto") {
                          // Launch external links using an external application
                          await launchUrl(uri);

                          // Prevent the WebView from loading the URL
                          return NavigationActionPolicy.CANCEL;
                        }

                        // Allow the WebView to load internal links
                        return NavigationActionPolicy.ALLOW;
                      },
                      onReceivedError: (controller, request, error) {
                        pullToRefreshController?.endRefreshing();

                        //
                        // setState(() {
                        //   isOffline = true;
                        // });
                      },
                      onProgressChanged: (controller, progress) {
                        setState(() {
                          this.progress = progress / 100;
                        });
                        if (progress > 50) {
                          controller.evaluateJavascript(source: footerScript);
                        }
                      },
                    ),

                    //
                    progress < 1.0
                        ? Center(
                            child: LoadingAnimationWidget.inkDrop(
                              size: 50,
                              color: Colors.orange,
                            ),
                          )
                        : !isOffline
                            ? Container()
                            : Center(
                                child: LoadingAnimationWidget.beat(
                                  size: 50,
                                  color: Colors.orange,
                                ),
                              ),

                    //
                    // progress < 1.0
                    //     ? LinearProgressIndicator(
                    //         value: progress,
                    //         backgroundColor: Colors.orange,
                    //       )
                    //     : !isOffline
                    //         ? Container()
                    //         : const LinearProgressIndicator(),
                  ],
                ),
        ),
      ),
      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepOrange,
        unselectedItemColor: Colors.grey,
        selectedFontSize: 14,
        unselectedFontSize: 14,
        selectedLabelStyle: const TextStyle(color: Colors.black),
        unselectedLabelStyle: const TextStyle(color: Colors.grey),
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.flash_on),
            label: 'Flash Sale',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.store),
            label: 'Shop',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: 'Cart',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.article),
            label: 'Blog',
          ),
        ],
      ),
    );
  }
}
