import 'package:flutter/material.dart';
import 'package:pjsk_sticker/font_manager.dart';

class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({super.key});

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

class _FontSettingsPageState extends State<FontSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _downloading = false;

  @override
  void initState() {
    super.initState();
    _registerAllFonts();
  }

  Future<void> _registerAllFonts() async {
    for (var font in FontManager.instance.fonts) {
      if (font.filePath != null) {
        await FontManager.instance.registerFont(font.name);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _addFont() async {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入字体名称')));
      return;
    }
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请输入下载地址')));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('URL 格式不正确')));
      return;
    }

    setState(() => _downloading = true);
    try {
      await FontManager.instance.downloadFont(name, url);
      await FontManager.instance.registerFont(name);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('字体 "$name" 下载成功')));
        _nameController.clear();
        _urlController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下载失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteFont(FontInfo font) async {
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除字体'),
            content: Text('确认删除字体 "${font.name}" 吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  '删除',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await FontManager.instance.deleteFont(font.name);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final fonts = FontManager.instance.fonts;

    return Scaffold(
      appBar: AppBar(title: const Text("字体管理")),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 64),
        children: [
          if (fonts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无字体，请在下方添加',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...fonts.map((font) => _buildFontTile(font)),
          const Divider(),
          ListTile(
            title: Text(
              "添加字体",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '字体名称',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: '下载地址',
                helperText: '仅支持 .ttf 和 .otf 格式，不支持 woff/woff2',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton.icon(
              onPressed: _downloading ? null : _addFont,
              icon:
                  _downloading
                      ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                      : const Icon(Icons.download),
              label: Text(_downloading ? '下载中...' : '下载并添加'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontTile(FontInfo font) {
    final bool downloaded = font.filePath != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: Icon(
            downloaded ? Icons.check_circle : Icons.cloud_download_outlined,
            color: downloaded ? Colors.green : Colors.grey,
          ),
          title: Text(font.name),
          subtitle: Text(
            font.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.delete_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => _deleteFont(font),
          ),
        ),
        if (downloaded)
          Padding(
            padding: const EdgeInsets.only(left: 72, right: 16, bottom: 12),
            child: Text(
              'わんだほーい',
              style: TextStyle(fontFamily: font.name, fontSize: 24),
            ),
          ),
      ],
    );
  }
}
