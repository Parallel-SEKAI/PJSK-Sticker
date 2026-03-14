import 'package:flutter/material.dart';
import 'package:pjsk_sticker/font_manager.dart';
import 'package:pjsk_sticker/l10n/app_localizations.dart';

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
    final s = S.of(context);
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.enterFontName)));
      return;
    }
    if (url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.enterDownloadUrl)));
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.urlFormatError)));
      return;
    }

    setState(() => _downloading = true);
    try {
      await FontManager.instance.downloadFont(name, url);
      await FontManager.instance.registerFont(name);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fontDownloadSuccess(name))));
        _nameController.clear();
        _urlController.clear();
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.downloadFailed(e.toString()))));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _deleteFont(FontInfo font) async {
    final s = S.of(context);
    final confirm = await showAdaptiveDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(s.deleteFont),
            content: Text(s.confirmDeleteFont(font.name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  s.delete,
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
    final s = S.of(context);
    final fonts = FontManager.instance.fonts;

    return Scaffold(
      appBar: AppBar(title: Text(s.fontManagement)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 64),
        children: [
          if (fonts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  s.noFontsHint,
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...fonts.map((font) => _buildFontTile(font)),
          const Divider(),
          ListTile(
            title: Text(
              s.addFont,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: s.fontName,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.label_outline),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _urlController,
              decoration: InputDecoration(
                labelText: s.downloadUrl,
                helperText: s.fontFormatHint,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.link),
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
              label: Text(_downloading ? s.downloading : s.downloadAndAdd),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFontTile(FontInfo font) {
    final bool downloaded = font.filePath != null;
    final s = S.of(context);
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
              s.fontPreviewText,
              style: TextStyle(fontFamily: font.name, fontSize: 24),
            ),
          ),
      ],
    );
  }
}
