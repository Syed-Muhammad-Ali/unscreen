// ignore_for_file: unused_local_variable, use_build_context_synchronously

import 'dart:convert';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class WebViewClass extends StatefulWidget {
  const WebViewClass({super.key});

  @override
  State<WebViewClass> createState() => _WebViewClassState();
}

class _WebViewClassState extends State<WebViewClass> {
  InAppWebViewController? webViewController;
  final ValueNotifier<bool> isPageLoadingNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _requestStoragePermission();
  }

  /// ✅ Handle Android 13+ and below separately
  Future<bool> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      List<Permission> permissions = [];
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        // permissions.add(Permission.photos);
        permissions.add(Permission.videos);
      } else {
        permissions.add(Permission.storage);
      }
      final statuses = await permissions.request();

      if (statuses.values.any((status) => !status.isGranted)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Photos/Videos permission required to save downloaded files.',
            ),
          ),
        );
        return false;
      }
      return true;
    } else {
      return false;
    }
  }

  Future<void> _handleDownload(String url, String? suggestedFilename) async {
    try {
      bool havePerm = await _requestStoragePermission();

      if (!havePerm) return;

      // ✅ Prepare directory
      final Dio dio = Dio();
      final Directory dir = Platform.isAndroid
          ? (await getExternalStorageDirectory())!
          : await getApplicationDocumentsDirectory();

      final String downloadsDir = "${dir.path}/Download";
      await Directory(downloadsDir).create(recursive: true);

      final String fileName = suggestedFilename ??
          "file_${DateTime.now().millisecondsSinceEpoch}.${url.split('.').last}";
      final String savePath = "$downloadsDir/$fileName";

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('⬇️ Downloading $fileName...')));

      // ✅ Download with progress feedback
      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
            debugPrint("Downloading: $progress%");
          }
        },
      );

      // ✅ Save to gallery (try both video & image)
      bool? success;
      if (fileName.endsWith('.mp4') ||
          fileName.endsWith('.mov') ||
          fileName.endsWith('.avi')) {
        success = await GallerySaver.saveVideo(savePath);
      } else if (fileName.endsWith('.jpg') ||
          fileName.endsWith('.jpeg') ||
          fileName.endsWith('.png') ||
          fileName.endsWith('.gif')) {
        success = await GallerySaver.saveImage(savePath);
      }

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Saved to gallery: $fileName')),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅ File saved: $savePath')));
      }
    } catch (e) {
      debugPrint("❌ Download error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Download failed: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        backgroundColor: Colors.black,
        elevation: 0,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              onPressed: () {
                webViewController?.reload();
              },
              icon: Icon(Icons.refresh))
        ],
        leading: InkWell(
          onTap: () async {
            // print(Platform.operatingSystemVersion);
            if (webViewController != null) {
              bool? canGoBack = await webViewController?.canGoBack();
              if (canGoBack ?? false) {
                await webViewController!.goBack();
              } else {
                Navigator.canPop(context);
              }
            }
          },
          child: Platform.isIOS
              ? const Icon(Icons.arrow_back_ios, size: 25, color: Colors.white)
              : const Icon(Icons.arrow_back, size: 20, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            InAppWebView(
              initialUrlRequest: URLRequest(
                url: WebUri("https://www.unscreen.com/"),
              ),
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                allowsInlineMediaPlayback: true,
                allowFileAccessFromFileURLs: true,
                allowUniversalAccessFromFileURLs: true,
                useOnDownloadStart: true,
              ),
              onWebViewCreated: (controller) {
                webViewController = controller;
              },
              onDownloadStartRequest: (controller, request) async {
                final url = request.url.toString();

                if (url.startsWith('blob:')) {
                  final filename = request.suggestedFilename ??
                      'download_${DateTime.now().millisecondsSinceEpoch}.gif';

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('🔄 Preparing download...')),
                  );

                  // ✅ Convert blob → base64 inside WebView
                  await controller.evaluateJavascript(source: """
        (async () => {
          try {
            const blob = await fetch("$url").then(r => r.blob());
            const reader = new FileReader();
            reader.onloadend = () => {
              const data = reader.result;
              console.log('BLOB_DATA:' + data);
            };
            reader.readAsDataURL(blob);
          } catch (err) {
            console.error('BLOB_ERROR:' + err);
          }
        })();
      """);
                } else {
                  // Normal download
                  await _handleDownload(url, request.suggestedFilename);
                }
              },

              /// ✅ Capture blob data here
              onConsoleMessage: (controller, consoleMessage) async {
                if (consoleMessage.message.startsWith('BLOB_DATA:')) {
                  final dataUrl =
                      consoleMessage.message.replaceFirst('BLOB_DATA:', '');
                  final base64String = dataUrl.split(',').last;
                  final filename =
                      'unscreen_${DateTime.now().millisecondsSinceEpoch}.gif';
                  await _saveBase64File(base64String, filename);
                } else if (consoleMessage.message.startsWith('BLOB_ERROR:')) {
                  debugPrint('❌ JS Blob Error: ${consoleMessage.message}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('❌ Failed to process blob data')),
                  );
                }
              },

              onLoadStart: (controller, url) {
                isPageLoadingNotifier.value = true;
              },
              onLoadStop: (controller, url) {
                isPageLoadingNotifier.value = false;
              },
              onReceivedError: (controller, request, error) {
                isPageLoadingNotifier.value = false;
              },
            ),

            /// Page Loading Indicator
            ValueListenableBuilder(
              valueListenable: isPageLoadingNotifier,
              builder: (context, bool value, _) {
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
          ],
        ),
      ),
    );
  }

  Future<void> _saveBase64File(String base64Data, String filename) async {
    try {
      bool havePerm = await _requestStoragePermission();
      if (!havePerm) return;

      final bytes = base64Decode(base64Data);
      final dir = Platform.isAndroid
          ? (await getExternalStorageDirectory())!
          : await getApplicationDocumentsDirectory();

      final downloadsDir = "${dir.path}/Download";
      await Directory(downloadsDir).create(recursive: true);

      final savePath = "$downloadsDir/$filename";
      final file = File(savePath);
      await file.writeAsBytes(bytes);

      bool? success;
      if (filename.endsWith('.mp4') ||
          filename.endsWith('.mov') ||
          filename.endsWith('.avi')) {
        success = await GallerySaver.saveVideo(savePath);
      } else {
        success = await GallerySaver.saveImage(savePath);
      }

      if (success == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Saved to gallery: $filename')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ File saved: $savePath')),
        );
      }
    } catch (e) {
      debugPrint('❌ File save error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Failed to save file: $e')),
      );
    }
  }
}
