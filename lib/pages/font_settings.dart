import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pjsk_sticker/font_manager.dart';
import 'package:pjsk_sticker/l10n/app_localizations.dart';

class FontSettingsPage extends StatefulWidget {
  const FontSettingsPage({super.key});

  @override
  State<FontSettingsPage> createState() => _FontSettingsPageState();
}

enum _AddFontMode { network, local }

class _FontSettingsPageState extends State<FontSettingsPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  bool _downloading = false;
  _AddFontMode _addMode = _AddFontMode.network;
  bool _addingLocalFont = false;

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

  /// 从文件路径提取字体名称
  String _extractFontNameFromPath(String path) {
    final fileName = p.basename(path);
    final nameWithoutExt = fileName.replaceAll(
      RegExp(r'\.(ttf|otf)$', caseSensitive: false),
      '',
    );
    final cleaned =
        nameWithoutExt.replaceAll('-', ' ').replaceAll('_', ' ').trim();
    return cleaned.isEmpty ? 'CustomFont' : cleaned;
  }

  /// 检查字体名称是否重复
  Future<bool> _checkDuplicateName(String name) async {
    final s = S.of(context);
    final existing = FontManager.instance.fonts.any((f) => f.name == name);

    if (!existing) return true;

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(s.fontAlreadyExists(name)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(s.overwrite),
              ),
            ],
          ),
    );

    return confirm ?? false;
  }

  /// 检查文件大小,超过 50MB 显示警告
  Future<bool> _checkFileSize(File file) async {
    final s = S.of(context);
    final size = await file.length();
    const warnSize = 50 * 1024 * 1024; // 50MB

    if (size <= warnSize) return true;

    final sizeMB = (size / (1024 * 1024)).toStringAsFixed(1);

    if (!mounted) return false;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(s.fontFileTooLarge(sizeMB)),
            content: Text(s.fontFileTooLargeHint),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(s.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(s.continueButton),
              ),
            ],
          ),
    );

    return confirm ?? false;
  }

  Future<void> _addLocalFont() async {
    final s = S.of(context);

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['ttf', 'otf'],
        dialogTitle: s.selectFontFile,
      );

      if (result == null || result.files.isEmpty) return;

      if (result.files.length != 1) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.multipleFilesSelected)));
        }
        return;
      }

      final filePath = result.files.single.path;
      if (filePath == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(s.fontFileReadFailed('Path is null'))),
          );
        }
        return;
      }

      final file = File(filePath);

      final bytes = await file.openRead(0, 4).first;
      if (!FontManager.isValidFontHeader(bytes)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.fontFormatInvalid)));
        }
        return;
      }

      if (!await _checkFileSize(file)) return;

      if (_nameController.text.trim().isEmpty) {
        final autoName = _extractFontNameFromPath(filePath);
        _nameController.text = autoName;
      }

      final name = _nameController.text.trim();

      if (name.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.enterFontName)));
        }
        return;
      }

      final shouldOverwrite = await _checkDuplicateName(name);
      if (!shouldOverwrite) return;

      setState(() => _addingLocalFont = true);

      final success = await FontManager.instance.addLocalFont(
        name: name,
        sourcePath: filePath,
        overwrite: shouldOverwrite,
      );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.fontAddSuccess(name))));
          _nameController.clear();
          setState(() {});
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(s.fontAlreadyExists(name))));
        }
      }
    } on FileSystemException catch (e) {
      if (mounted) {
        final message = e.osError?.message ?? e.toString();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(s.fontFileReadFailed(message))));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.fontFileReadFailed(e.toString()))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _addingLocalFont = false);
      }
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
            child: SegmentedButton<_AddFontMode>(
              segments: [
                ButtonSegment(
                  value: _AddFontMode.network,
                  label: Text(s.fromNetwork),
                  icon: const Icon(Icons.cloud_download),
                ),
                ButtonSegment(
                  value: _AddFontMode.local,
                  label: Text(s.fromLocal),
                  icon: const Icon(Icons.folder_open),
                ),
              ],
              selected: {_addMode},
              onSelectionChanged: (Set<_AddFontMode> newSelection) {
                setState(() {
                  _addMode = newSelection.first;
                });
              },
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
          if (_addMode == _AddFontMode.network) ...[
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
          if (_addMode == _AddFontMode.local) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton.icon(
                onPressed: _addingLocalFont ? null : _addLocalFont,
                icon:
                    _addingLocalFont
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.folder_open),
                label: Text(
                  _addingLocalFont ? s.addingFont : s.selectFromLocal,
                ),
              ),
            ),
          ],
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
