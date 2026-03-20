part of '../sticker.dart';

extension _StickerPageLogic on _StickerPageState {
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
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
  }

  void _debouncedCreateSticker() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _createSticker();
    });
  }

  Future<void> _createSticker() async {
    await _savePreferences();
    String char = _character != _StickerPageState.kRandom ? _character : "";
    if (PjskGenerator.groups.contains(char)) {
      final members = PjskGenerator.groupMembers[char]!;
      char = members[DateTime.now().millisecond % members.length];
    }
    char = PjskGenerator.characterMap[char] ?? char;
    if (_selectedSticker != -1) char = '$char$_selectedSticker';

    _byteData = await PjskGenerator.pjsk(layers: _layers, character: char);
    if (mounted) {
      _update(() {});
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
  String? _findGroupForCharacter(String? character) {
    if (character == null) return null;
    for (var entry in PjskGenerator.groupMembers.entries) {
      if (entry.value.contains(character)) return entry.key;
    }
    String? display;
    try {
      display =
          PjskGenerator.characterMap.entries
              .firstWhere((e) => e.value == character)
              .key;
    } catch (_) {}
    if (display != null) {
      for (var entry in PjskGenerator.groupMembers.entries) {
        if (entry.value.contains(display)) return entry.key;
      }
    }
    return null;
  }

  Color _getThemeColor() {
    final charKey = PjskGenerator.characterMap[_character];
    if (charKey != null && PjskGenerator.characterColor.containsKey(charKey)) {
      return PjskGenerator.characterColor[charKey]!;
    }
    if (PjskGenerator.groupColor.containsKey(_character)) {
      return PjskGenerator.groupColor[_character]!;
    }
    return Theme.of(context).colorScheme.primary;
  }
}
