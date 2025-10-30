import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unscreen/screen/splash/splash_screen.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WebViewClass extends StatefulWidget {
  const WebViewClass({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _WebViewClassState createState() => _WebViewClassState();
}

class _WebViewClassState extends State<WebViewClass> {
  WebViewController webViewController = WebViewController();
  final ValueNotifier<bool> isloadingNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<bool> isPageLoadingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    webViewController = WebViewController();
    requestAllPermissions();
    Future.delayed(const Duration(milliseconds: 5000), () {
      isloadingNotifier.value = false;
    });
    super.initState();
  }

  Future<void> requestAllPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.microphone,
      Permission.photos, // iOS & Android 13+
      Permission.videos,
      Permission.storage, // For older Android
    ].request();

    // Optional: Check which permissions are denied
    statuses.forEach((permission, status) {
      if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint("⚠️ Permission denied: $permission");
      }
    });
  }

  Future<void> clearWebViewCache() async {
    await webViewController.clearCache();
    // await webViewController.clearCookies();
    // await clearCookies();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        leading: InkWell(
          onTap: () async {
            if (webViewController != null) {
              await clearWebViewCache(); // Clear cache before going back

              webViewController.goBack();
            }
          },
          child: Platform.isIOS
              ? Icon(Icons.arrow_back_ios, size: 25, color: Colors.white)
              : Icon(Icons.arrow_back, size: 20, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(
              controller: webViewController
                ..loadRequest(Uri.parse('https://www.unscreen.com/'))
                ..setJavaScriptMode(JavaScriptMode.unrestricted)
                ..setNavigationDelegate(
                  NavigationDelegate(
                    onProgress: (int progress) {
                      // Update loading bar.
                    },
                    onPageStarted: (String url) {
                      if (!isPageLoadingNotifier.value) {
                        isPageLoadingNotifier.value = true;
                      }
                    },
                    onPageFinished: (String url) {
                      if (isPageLoadingNotifier.value) {
                        isPageLoadingNotifier.value = false;
                      }
                    },
                    onWebResourceError: (WebResourceError error) {
                      // isPageLoadingNotifier.value=false;
                    },
                  ),
                ),
            ),
            ValueListenableBuilder(
              valueListenable: isPageLoadingNotifier,
              builder: (BuildContext context, bool value, Widget? child) {
                return value
                    ? Container(
                        color: Colors.grey.withOpacity(0.3),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color.fromARGB(255, 3, 144, 215),
                            backgroundColor: Colors.grey,
                          ),
                        ),
                      )
                    : const SizedBox();
              },
            ),
            ValueListenableBuilder(
              valueListenable: isloadingNotifier,
              builder: (BuildContext context, bool value, Widget? child) {
                return value ? const SplashScreen() : const SizedBox();
              },
            ),
            //
          ],
        ),
      ),
    );
  }
}
