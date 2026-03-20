part of '../sticker.dart';

extension _StickerPageConfig on _StickerPageState {
  Uri _saveAsUri() {
    final Map<String, dynamic> params = {
      'character': _character,
      'layers_json': jsonEncode(_layers.map((l) => l.toJson()).toList()),
    };

    if (_selectedSticker != -1) {
      params['character_index'] = _selectedSticker.toString();
    }

    return _StickerPageState._apiBaseUrl.replace(queryParameters: params);
  }

  void _reloadFromUri(Uri uri) {
    final Map<String, List<String>> queryParams = uri.queryParametersAll;
    _update(() {
      _character = queryParams['character']?.first ?? _character;
      _selectedSticker =
          int.tryParse(queryParams['character_index']?.first ?? '') ??
          _selectedSticker;

      final String? layersJson = queryParams['layers_json']?.first;
      if (layersJson != null) {
        try {
          final List<dynamic> list = jsonDecode(layersJson);
          _layers = list.map((item) => TextLayer.fromJson(item)).toList();
          _currentLayerId = _layers.first.id;
          _contextController.text = _currentLayer.content;
        } catch (e) {
          if (kDebugMode) print("Error reloading layers from URI: $e");
        }
      } else {
        // 兼容旧版单一图层参数
        String content = queryParams['text']?.first ?? "わんだほーい";
        double fontSize =
            double.tryParse(queryParams['font_size']?.first ?? '') ?? 42;
        int edgeSize =
            int.tryParse(queryParams['stroke_width']?.first ?? '') ?? 4;
        double lean =
            double.tryParse(queryParams['rotation_angle']?.first ?? '') ?? 15;
        Offset pos = const Offset(20, 10);
        if (queryParams['position']?.length == 2) {
          pos = Offset(
            double.tryParse(queryParams['position']![0]) ?? 20,
            double.tryParse(queryParams['position']![1]) ?? 10,
          );
        }
        int font = 0;
        if (queryParams['font_path'] != null) {
          final int fontIndex = PjskGenerator.fonts.indexOf(
            queryParams['font_path']!.first,
          );
          if (fontIndex != -1) font = fontIndex;
        }
        bool useCustomColor = false;
        Color customColor = const Color(0xFFDDAACC);
        if (queryParams['text_color']?.length == 3) {
          final r = int.tryParse(queryParams['text_color']![0]) ?? 221;
          final g = int.tryParse(queryParams['text_color']![1]) ?? 170;
          final b = int.tryParse(queryParams['text_color']![2]) ?? 204;
          useCustomColor = true;
          customColor = Color.fromARGB(255, r, g, b);
        }

        _layers = [
          TextLayer(
            content: content,
            fontSize: fontSize,
            edgeSize: edgeSize,
            lean: lean,
            pos: pos,
            font: font,
            useCustomColor: useCustomColor,
            customColor: customColor,
          ),
        ];
        _currentLayerId = _layers.first.id;
        _contextController.text = _currentLayer.content;
      }
    });
    _createSticker();
  }

  // ignore: unused_element
  Future<void> _exportImportConfig() async {
    if (!mounted) return;
    final TextEditingController configController = TextEditingController(
      text: _saveAsUri().toString(),
    );
    showAdaptiveDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).exportImportConfig),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(S.of(context).exportImportHint),
                const SizedBox(height: 8),
                TextField(
                  controller: configController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: S.of(context).pasteConfigHint,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              if (Platform.isAndroid)
                TextButton(
                  onPressed:
                      () async => await SharePlus.instance.share(
                        ShareParams(
                          text: S
                              .of(context)
                              .shareEmojiText(configController.text),
                          title: S.of(context).shareConfigTitle,
                        ),
                      ),
                  child: Text(S.of(context).share),
                ),
              TextButton(
                onPressed: () {
                  configController.text = _saveAsUri().toString();
                  Clipboard.setData(ClipboardData(text: configController.text));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(S.of(context).copied)));
                },
                child: Text(S.of(context).copy),
              ),
              TextButton(
                onPressed: () async {
                  final ClipboardData? raw = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  if (raw?.text != null) {
                    final match = _urlReg.firstMatch(raw!.text!);
                    if (match != null) configController.text = match.group(0)!;
                  }
                },
                child: Text(S.of(context).paste),
              ),
              TextButton(
                onPressed: () {
                  final String text = configController.text.trim();
                  if (text.isNotEmpty) {
                    try {
                      final Uri uri = Uri.parse(text);
                      Navigator.pop(context);
                      _reloadFromUri(uri);
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(S.of(context).configFormatError),
                        ),
                      );
                    }
                  }
                },
                child: Text(S.of(context).importAction),
              ),
            ],
          ),
    );
  }
}
