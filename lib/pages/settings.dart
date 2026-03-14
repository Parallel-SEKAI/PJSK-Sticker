import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:pjsk_sticker/pages/font_settings.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String? qq;
  List<String> qqurls = [];

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
        SnackBar(content: Text('${message ?? uris.first} 链接打开失败')),
      );
      await launchUrl(uris.first);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("设置")),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.font_download_outlined),
            title: const Text("字体管理"),
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
              "关于",
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
            title: const Text("版本"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("2.1.0"),
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
            title: const Text("开发"),
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
            title: const Text("QQ 群聊"),
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
                ).showSnackBar(const SnackBar(content: Text("正在获取QQ群号")));
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
              "赞赏",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: const Text("微信赞赏码"),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              showAdaptiveDialog(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text("微信赞赏码"),
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
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("已保存到 Pictures/wechat.png"),
                              ),
                            );
                          },
                          child: const Text("保存"),
                        ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("关闭"),
                      ),
                    ],
                  );
                },
              );
            },
          ),
          ListTile(
            title: const Text("爱发电"),
            trailing: const Icon(Icons.chevron_right, size: 18),
            onTap: () {
              toUris([Uri.parse("https://afdian.com/a/Parallel-SEKAI")]);
            },
          ),
          const Divider(),
          // --- 致谢 ---
          ListTile(
            title: Text(
              "致谢",
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
