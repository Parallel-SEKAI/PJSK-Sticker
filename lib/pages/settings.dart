import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pjsk_sticker/build_info.dart';
import 'package:pjsk_sticker/l10n/app_localizations.dart';
import 'package:pjsk_sticker/pages/font_settings.dart';
import 'package:pjsk_sticker/update/update_checker.dart';
import 'package:pjsk_sticker/update/update_prompt.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? qq;
  List<String> qqurls = [];
  final UpdateChecker _updateChecker = UpdateChecker();
  bool _isCheckingUpdates = false;

  @override
  void initState() {
    super.initState();
    getGroupNumber().then((value) {
      qq = value;
      if (mounted) setState(() {});
    });
    getGroupUrls().then((value) {
      qqurls = value;
      if (mounted) setState(() {});
    });
  }

  Future<String> getGroupNumber() async {
    final response = await http.get(
      Uri.parse('https://xiaocaoooo.github.io/musiku/qq'),
    );
    if (response.statusCode == 200) {
      return response.body.trim();
    } else {
      throw Exception('Failed to load group number');
    }
  }

  Future<List<String>> getGroupUrls() async {
    final response = await http.get(
      Uri.parse('https://xiaocaoooo.github.io/musiku/qqurl'),
    );
    if (response.statusCode == 200) {
      return response.body.trim().split('\n');
    } else {
      throw Exception('Failed to load group urls');
    }
  }

  Future<void> toUris(List<Uri> uris, {String? message}) async {
    for (var uri in uris) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return;
      }
    }
    if (mounted) {
      if (message != null) {
        Clipboard.setData(ClipboardData(text: message));
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).linkOpenFailed(message ?? uris.first.toString()),
          ),
        ),
      );
      await launchUrl(uris.first);
    }
  }

  String _formatBuildTime(BuildContext context) {
    final DateTime? buildTime = BuildInfo.buildTime;
    if (buildTime == null) {
      return '-';
    }

    final String localeName = Localizations.localeOf(context).toString();
    return DateFormat.yMd(localeName).add_Hms().format(buildTime.toLocal());
  }

  Future<void> _checkUpdatesManually() async {
    if (_isCheckingUpdates) {
      return;
    }

    final S s = S.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _isCheckingUpdates = true;
    });

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(s.checkingForUpdates),
        duration: const Duration(seconds: 1),
      ),
    );

    try {
      final updateInfo = await _updateChecker.checkForUpdate(manual: true);
      if (!mounted) {
        return;
      }

      messenger.hideCurrentSnackBar();
      if (updateInfo == null) {
        messenger.showSnackBar(SnackBar(content: Text(s.alreadyLatestVersion)));
        return;
      }

      await showUpdateDialog(
        context: context,
        checker: _updateChecker,
        updateInfo: updateInfo,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(s.updateCheckFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdates = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.settings)),
      body: ListView(
        children: [
          ListTile(
            // leading: const Icon(Icons.font_download_outlined),
            title: Text(s.fontManagement),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (ctx) => const FontSettingsPage()),
              );
            },
          ),
          const Divider(),
          // --- 关于 ---
          ListTile(
            title: Text(
              s.about,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: const Text("Project Sekai Sticker"),
            subtitle: const Text("Wonderhoy!"),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('こんにちわんだーはい')));
            },
          ),
          ListTile(
            title: Text(s.version),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(BuildInfo.appVersion),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse(
                  "https://github.com/Parallel-SEKAI/PJSK-Sticker/releases/",
                ),
              ]);
            },
          ),
          ListTile(
            title: Text(s.checkForUpdates),
            trailing:
                _isCheckingUpdates
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.chevron_right, size: 18),
            onTap: _isCheckingUpdates ? null : _checkUpdatesManually,
          ),
          ListTile(
            title: Text(s.buildTime),
            trailing: Text(_formatBuildTime(context)),
          ),
          ListTile(
            title: Text(s.developer),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Parallel-SEKAI Team"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://github.com/Parallel-SEKAI/")]);
            },
          ),
          ListTile(
            title: const Text("Github"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Parallel-SEKAI/PJSK-Sticker"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse("https://github.com/Parallel-SEKAI/PJSK-Sticker/"),
              ]);
            },
          ),
          ListTile(
            title: Text(s.qqGroup),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(qq ?? ""),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              if (qq == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(s.fetchingQQGroup)));
              } else {
                toUris([
                  Uri.parse(
                    "mqqapi://card/show_pslcard?src_type=internal&version=1&uin=$qq&card_type=group&source=qrcode",
                  ),
                  ...qqurls.map((url) => Uri.parse(url)),
                ], message: qq);
              }
            },
          ),
          const Divider(),
          // --- 赞赏 ---
          ListTile(
            title: Text(
              s.appreciation,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: Text(s.wechatQR),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              showAdaptiveDialog(
                context: context,
                builder: (dialogContext) {
                  return AlertDialog(
                    title: Text(s.wechatQR),
                    content: Image.asset(
                      "assets/wechat.png",
                      width: 200,
                      height: 200,
                    ),
                    actions: [
                      if (Platform.isAndroid)
                        TextButton(
                          onPressed: () async {
                            final File file = File(
                              '/storage/emulated/0/Pictures/wechat.png',
                            );
                            final bytes =
                                (await rootBundle.load(
                                  "assets/wechat.png",
                                )).buffer.asUint8List();
                            file.writeAsBytesSync(bytes);
                            if (!dialogContext.mounted) return;
                            ScaffoldMessenger.of(dialogContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  s.savedToPath("Pictures/wechat.png"),
                                ),
                              ),
                            );
                          },
                          child: Text(s.save),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        child: Text(s.close),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: Text(s.afdian),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              toUris([Uri.parse("https://afdian.com/a/Parallel-SEKAI")]);
            },
          ),
          const Divider(),
          // --- 致谢 ---
          ListTile(
            title: Text(
              s.credits,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: const Text("プロセカ"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("SEGA"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://pjsekai.sega.jp/")]);
            },
          ),
          ListTile(
            title: const Text("flutter"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("flutter"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://github.com/flutter/flutter/")]);
            },
          ),
          ListTile(
            title: const Text("Project_Sekai_Stickers_QQBot"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("sszzz830"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse(
                  "https://github.com/sszzz830/Project_Sekai_Stickers_QQBot/",
                ),
              ]);
            },
          ),
          ListTile(
            title: const Text("sekai-stickers"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("TheOriginalAyaka"),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, size: 18),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse(
                  "https://github.com/TheOriginalAyaka/sekai-stickers/",
                ),
              ]);
            },
          ),
        ],
      ),
    );
  }
}
