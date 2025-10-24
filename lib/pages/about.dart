import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
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
      throw Exception('Failed to load group number');
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
      appBar: AppBar(
        title: const Text("关于"),
        leading: IconButton(
          icon: Icon(
            Ionicons.arrow_back,
            color: Theme.of(context).colorScheme.onSurface, // 图标颜色(跟随主题)
            size: 24, // 图标大小
          ),
          onPressed: () => Navigator.pop(context), // 点击返回上一页
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(
              "Project Sekai Sticker",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: Text("Wonderhoy!"),
            trailing: Text(":)"),
            onTap: () {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('こんにちわんだーはい')));
            },
          ),
          ListTile(
            title: Text("版本"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("1.1.2"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse(
                  "https://github.com/xiaocaoooo/pjsk-sticker/releases/",
                ),
              ]);
            },
          ),
          ListTile(
            title: Text("开发"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("xiaocaoooo"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://github.com/xiaocaoooo/")]);
            },
          ),
          ListTile(
            title: Text("Github"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("xiaocaoooo/pjsk-sticker"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              toUris([
                Uri.parse("https://github.com/xiaocaoooo/pjsk-sticker/"),
              ]);
            },
          ),
          ListTile(
            title: Text("QQ 群聊"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text(qq ?? ""), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              if (qq == null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text("正在获取QQ群号")));
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
          ListTile(
            title: Text(
              "致谢",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          ListTile(
            title: Text("プロセカ"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("SEGA"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://pjsekai.sega.jp/")]);
            },
          ),
          ListTile(
            title: Text("flutter"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("flutter"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
              ],
            ),
            onTap: () {
              toUris([Uri.parse("https://github.com/flutter/flutter/")]);
            },
          ),
          ListTile(
            title: Text("Project_Sekai_Stickers_QQBot"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("sszzz830"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
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
            title: Text("sekai-stickers"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min, // 仅占必要宽度
              children: [
                Text("TheOriginalAyaka"), // 原文字
                SizedBox(width: 8), // 文字和箭头的间距
                Icon(
                  Ionicons.chevron_forward, // 箭头图标
                  size: 18, // 图标大小（略小于默认，更协调）透明效果
                ),
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
