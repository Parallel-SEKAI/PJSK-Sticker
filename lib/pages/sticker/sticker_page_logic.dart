part of '../sticker.dart';

extension _StickerPageLogic on _StickerPageState {
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    // 加载自定义底图路径并验证文件存在性
    String? customBgPath = prefs.getString('customBgPath');
    if (customBgPath != null && customBgPath.isEmpty) {
      customBgPath = null;
    }
    if (customBgPath != null) {
      final file = File(customBgPath);
      if (!await file.exists()) {
        customBgPath = null;
        await prefs.remove('customBgPath');
      }
    }

    _update(() {
      _selectedGroup = prefs.getString('selectedGroup');
      _selectedCharacter = prefs.getString('selectedCharacter') ?? "emu";
      _selectedSticker = prefs.getInt('selectedSticker') ?? 12;
      _character = prefs.getString('character') ?? "emu";

      // 迁移旧的 "随机" 值
      if (_character == "随机") _character = _StickerPageState.kRandom;
      if (_selectedGroup == "随机") _selectedGroup = _StickerPageState.kRandom;

      final String? layersJson = prefs.getString('layers');
      if (layersJson != null && layersJson.isNotEmpty) {
        try {
          final List<dynamic> list = jsonDecode(layersJson);
          _layers = list.map((item) => TextLayer.fromJson(item)).toList();
          if (_layers.isEmpty) throw Exception("Empty layers");
        } catch (e) {
          if (kDebugMode) print("Error loading layers: $e");
          _layers = [TextLayer(content: "わんだほーい")];
          // 清理损坏的数据防止循环报错
          prefs.remove('layers');
        }
      } else {
        // 迁移旧数据
        _layers = [
          TextLayer(
            content: prefs.getString('content') ?? "わんだほーい",
            pos: Offset(
              prefs.getDouble('posX') ?? 20,
              prefs.getDouble('posY') ?? 10,
            ),
            fontSize: prefs.getDouble('fontSize') ?? 42,
            edgeSize: prefs.getInt('edgeSize') ?? 4,
            lean: prefs.getDouble('lean') ?? 15,
            font: prefs.getInt('font') ?? 0,
            useCustomColor: prefs.getBool('useCustomColor') ?? false,
            customColor: Color(prefs.getInt('customColor') ?? 0xFFDDAACC),
          ),
        ];
      }
      _currentLayerId = _layers.first.id;
      _contextController.text = _currentLayer.content;
      _customBgPath = customBgPath;
    });
    _createSticker();
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selectedGroup', _selectedGroup ?? '');
    await prefs.setString('selectedCharacter', _selectedCharacter ?? 'emu');
    await prefs.setInt('selectedSticker', _selectedSticker);
    await prefs.setString('character', _character);
    await prefs.setString(
      'layers',
      jsonEncode(_layers.map((l) => l.toJson()).toList()),
    );
    if (_customBgPath != null && _customBgPath!.isNotEmpty) {
      await prefs.setString('customBgPath', _customBgPath!);
    } else {
      await prefs.remove('customBgPath');
    }
  }

  void _debouncedCreateSticker() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _createSticker();
    });
  }

  Future<void> _createSticker() async {
    final currentId = ++_stickerGenerationId;

    await _savePreferences();
    String char = _character != _StickerPageState.kRandom ? _character : "";
    if (PjskGenerator.groups.contains(char)) {
      final members = PjskGenerator.groupMembers[char]!;
      char = members[DateTime.now().millisecond % members.length];
    }
    char = PjskGenerator.characterMap[char] ?? char;
    if (_selectedSticker != -1) char = '$char$_selectedSticker';

    // 按需加载自定义底图
    Uint8List? customBytes;
    if (_customBgPath != null) {
      try {
        final file = File(_customBgPath!);
        if (await file.exists()) {
          customBytes = await file.readAsBytes();
        } else {
          _customBgPath = null;
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('customBgPath');
        }
      } catch (e) {
        if (kDebugMode) print('Failed to load custom background: $e');
        _customBgPath = null;
      }
    }

    final result = await PjskGenerator.pjsk(
      layers: _layers,
      character: char,
      customImageBytes: customBytes,
    );

    // 只有最新的请求才更新 UI
    if (currentId == _stickerGenerationId && mounted) {
      _update(() {
        _byteData = result;
      });
    }
  }

  Future<void> _handleImageTap() async {
    if (_byteData == null) return;
    try {
      final path =
          Platform.isAndroid
              ? '/storage/emulated/0/Pictures/pjsk_sticker/pjsk_${DateTime.now().millisecondsSinceEpoch}.png'
              : 'pjsk_sticker/pjsk_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.create(recursive: true);
      await file.writeAsBytes(_byteData!);
      if (Platform.isAndroid) {
        await SharePlus.instance.share(
          ShareParams(files: [XFile.fromData(_byteData!, path: file.path)]),
        );
      } else if (Platform.isWindows) {
        await Process.run('explorer.exe', [
          '/select,${file.path.replaceAll('/', '\\')}',
        ]);
        Pasteboard.writeFiles([file.path.replaceAll('/', '\\')]);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Platform.isAndroid
                  ? S.of(context).savedToGallery
                  : S.of(context).copiedAndSaved,
            ),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print(e);
    }
  }

  // --- 6. 辅助方法 ---
  Color _getThemeColor() {
    // 使用自定义底图时，采用系统动态取色（Material You）
    if (_customBgPath != null) {
      return Theme.of(context).colorScheme.primary;
    }
    final charKey = PjskGenerator.characterMap[_character];
    if (charKey != null && PjskGenerator.characterColor.containsKey(charKey)) {
      return PjskGenerator.characterColor[charKey]!;
    }
    if (PjskGenerator.groupColor.containsKey(_character)) {
      return PjskGenerator.groupColor[_character]!;
    }
    return Theme.of(context).colorScheme.primary;
  }

  Future<void> _pickCustomBackground() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    final bytes = await picked.readAsBytes();

    // 添加文件大小检查（限制 5MB）
    if (bytes.length > 5 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(S.of(context).fileTooLarge)));
      }
      return;
    }

    // 验证文件头 magic bytes，仅允许 PNG/JPEG/GIF/WebP
    if (!_isValidImageBytes(bytes)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).invalidImageFormat)),
        );
      }
      return;
    }

    // 复制到应用私有目录
    final appDir = await getApplicationDocumentsDirectory();
    final customBgFile = File('${appDir.path}/custom_background.png');
    await customBgFile.writeAsBytes(bytes);

    _update(() {
      _customBgPath = customBgFile.path;
    });
    _createSticker();
  }

  /// 通过 magic bytes 验证是否为支持的图片格式（PNG/JPEG/GIF/WebP）
  static bool _isValidImageBytes(Uint8List bytes) {
    if (bytes.length < 12) return false;

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    if (bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return true;
    }

    // JPEG: FF D8 FF
    if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
      return true;
    }

    // GIF: 47 49 46 38 (GIF87a / GIF89a)
    if (bytes[0] == 0x47 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x38) {
      return true;
    }

    // WebP: RIFF....WEBP
    if (bytes[0] == 0x52 &&
        bytes[1] == 0x49 &&
        bytes[2] == 0x46 &&
        bytes[3] == 0x46 &&
        bytes[8] == 0x57 &&
        bytes[9] == 0x45 &&
        bytes[10] == 0x42 &&
        bytes[11] == 0x50) {
      return true;
    }

    return false;
  }

  Future<void> _clearCustomBackground() async {
    if (_customBgPath != null) {
      try {
        final file = File(_customBgPath!);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        if (kDebugMode) print('Failed to delete custom background: $e');
      }
    }
    _update(() {
      _customBgPath = null;
    });
    _createSticker();
  }
}
