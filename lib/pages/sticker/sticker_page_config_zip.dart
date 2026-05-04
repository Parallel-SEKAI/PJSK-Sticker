part of '../sticker.dart';

extension _StickerPageConfigZip on _StickerPageState {
  /// 导出配置 ZIP
  Future<void> _exportConfigZip() async {
    if (!mounted) return;

    // 1. 弹出对话框让用户输入贴纸名称
    final TextEditingController nameController = TextEditingController(
      text:
          _currentLayer.content.isNotEmpty
              ? _currentLayer.content
              : 'my_sticker',
    );

    final String? stickerName = await showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).exportConfigZip),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context).exportConfigZipHint),
                const SizedBox(height: 16),
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: S.of(context).stickerName,
                    hintText: S.of(context).stickerNameHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  final name = nameController.text.trim();
                  Navigator.pop(context, name.isEmpty ? 'my_sticker' : name);
                },
                child: Text(S.of(context).confirm),
              ),
            ],
          ),
    );

    if (stickerName == null) return;

    try {
      // 2. 准备导出数据
      String? characterId;
      int? imageId;
      Uint8List? customBgBytes;

      // 判断是内置底图还是自定义底图
      if (_customBgPath != null) {
        // 自定义底图：读取文件
        final file = File(_customBgPath!);
        if (await file.exists()) {
          customBgBytes = await file.readAsBytes();
        }
      } else {
        // 内置底图：提取 characterId 和 imageId
        characterId = _character;
        if (_selectedSticker != -1) {
          imageId = _selectedSticker;
        }
      }

      // 3. 调用核心服务导出
      final Uint8List zipBytes = StickerConfigArchive.exportSingleSticker(
        packName: stickerName,
        stickerId: 'sticker_${DateTime.now().millisecondsSinceEpoch}',
        stickerName: stickerName,
        characterId: characterId ?? 'emu',
        imageId: imageId ?? 1,
        layers: _layers,
        customBackgroundBytes: customBgBytes,
      );

      // 4. 保存文件
      if (!mounted) return;
      final String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: S.of(context).exportConfigZip,
        fileName: '$stickerName.pjsksticker.zip',
        type: FileType.custom,
        allowedExtensions: ['zip'],
        bytes: zipBytes,
      );

      if (outputPath != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).exportSuccess)));
      }
    } catch (e) {
      if (kDebugMode) print('Export config zip failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).exportFailed(e.toString()))),
        );
      }
    }
  }

  /// 导入配置 ZIP
  Future<void> _importConfigZip() async {
    if (!mounted) return;

    try {
      // 1. 选择文件
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final PlatformFile file = result.files.first;
      if (file.bytes == null) {
        throw Exception('无法读取文件内容');
      }

      // 2. 调用核心服务导入
      final importResult = StickerConfigArchive.importFromZip(file.bytes!);
      final stickers = importResult['stickers'] as List<dynamic>;

      if (stickers.isEmpty) {
        throw Exception('ZIP 文件中没有贴纸配置');
      }

      // 取第一个贴纸
      final stickerData = stickers.first as Map<String, dynamic>;
      String? customBgPath;

      // 如果有自定义底图，保存到应用目录
      if (stickerData['customBackgroundBytes'] != null) {
        final bgBytes = stickerData['customBackgroundBytes'] as Uint8List;
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final bgFile = File('${appDir.path}/custom_bg_imported_$timestamp.png');
        await bgFile.writeAsBytes(bgBytes);
        customBgPath = bgFile.path;
      }

      final config = ImportedStickerConfig(
        layers: stickerData['layers'] as List<TextLayer>,
        characterId: stickerData['characterId'] as String?,
        imageId: stickerData['imageId'] as int?,
        customBackgroundPath: customBgPath,
      );

      // 3. 应用配置到当前状态
      await _applyImportedConfig(config);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).importSuccess)));
      }
    } catch (e) {
      if (kDebugMode) print('Import config zip failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).importFailed(e.toString()))),
        );
      }
    }
  }

  /// 应用导入的配置
  Future<void> _applyImportedConfig(ImportedStickerConfig config) async {
    _update(() {
      // 恢复图层
      _layers = config.layers;
      _currentLayerId = _layers.isNotEmpty ? _layers.first.id : null;
      if (_currentLayerId != null) {
        _contextController.text = _currentLayer.content;
      }

      // 恢复底图
      if (config.customBackgroundPath != null) {
        // 自定义底图：使用已保存的路径
        _customBgPath = config.customBackgroundPath;
        _character = 'emu'; // 重置为默认
        _selectedSticker = -1;
      } else if (config.characterId != null) {
        // 内置底图：恢复角色和贴纸
        _character = config.characterId!;
        _selectedSticker = config.imageId ?? -1;
        _customBgPath = null;

        // 更新选择器状态
        _selectedCharacter = config.characterId;
        _selectedGroup = _findGroupForCharacter(config.characterId!);
      }
    });

    // 重新生成贴纸
    await _createSticker();
  }

  /// 显示配置管理对话框（包含 URI 和 ZIP 两种方式）
  Future<void> _showConfigManagementDialog() async {
    if (!mounted) return;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).configManagement),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.link),
                  title: Text(S.of(context).exportImportConfig),
                  subtitle: Text(S.of(context).exportImportHint),
                  onTap: () {
                    Navigator.pop(context);
                    _exportImportConfig();
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.folder_zip),
                  title: Text(S.of(context).exportConfigZip),
                  subtitle: Text(S.of(context).exportConfigZipHint),
                  onTap: () {
                    Navigator.pop(context);
                    _exportConfigZip();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.upload_file),
                  title: Text(S.of(context).importConfigZip),
                  subtitle: Text(S.of(context).importConfigZipHint),
                  onTap: () {
                    Navigator.pop(context);
                    _importConfigZip();
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).close),
              ),
            ],
          ),
    );
  }
}

/// 导入的贴纸配置数据结构
class ImportedStickerConfig {
  final List<TextLayer> layers;
  final String? characterId;
  final int? imageId;
  final String? customBackgroundPath; // 已保存到应用目录的路径

  ImportedStickerConfig({
    required this.layers,
    this.characterId,
    this.imageId,
    this.customBackgroundPath,
  });
}
