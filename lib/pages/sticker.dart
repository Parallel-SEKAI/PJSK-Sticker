import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:pjsk_sticker/font_manager.dart';
import 'package:pjsk_sticker/l10n/app_localizations.dart';
import 'package:pjsk_sticker/pages/settings.dart';
import 'package:pjsk_sticker/sticker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StickerPage extends StatefulWidget {
  const StickerPage({super.key});
  @override
  State<StickerPage> createState() => _StickerPageState();
}

class _StickerPageState extends State<StickerPage> {
  static const String kRandom = '__random__';

  // --- 1. 常量与 Keys ---
  static final Uri _apiBaseUrl = Uri.parse(
    "https://api.parallel-sekai.org/pjsk-sticker",
  );
  final RegExp _urlReg = RegExp(
    _apiBaseUrl.toString() + r"[\w\-._~:/?#[\]@!$&'()*+,;=%]+",
    caseSensitive: false,
  );

  late final Map<String, GlobalKey> _groupKeys = {
    kRandom: GlobalKey(),
    for (var g in PjskGenerator.groups) g: GlobalKey(),
  };
  late final Map<String, GlobalKey> _characterKeys = {
    for (var charList in PjskGenerator.groupMembers.values)
      for (var char in charList) char: GlobalKey(),
  };
  final Map<String, GlobalKey> _stickerKeys = {};

  // --- 2. 状态变量 ---
  Timer? _debounceTimer;
  final TextEditingController _contextController = TextEditingController();
  String? _selectedGroup;
  String? _selectedCharacter = "emu";
  int _selectedSticker = 12;
  String _character = "emu";
  Uint8List? _byteData;

  List<TextLayer> _layers = [TextLayer(content: "わんだほーい")];
  String? _currentLayerId;

  TextLayer get _currentLayer {
    if (_layers.isEmpty) {
      _layers = [TextLayer(content: "わんだほーい")];
      _currentLayerId = _layers.first.id;
    }
    return _layers.firstWhere(
      (l) => l.id == _currentLayerId,
      orElse: () => _layers.first,
    );
  }

  // --- 3. 生命周期与持久化 ---
  @override
  void initState() {
    super.initState();
    _currentLayerId = _layers.first.id;
    _loadPreferences();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _contextController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedGroup = prefs.getString('selectedGroup');
      _selectedCharacter = prefs.getString('selectedCharacter') ?? "emu";
      _selectedSticker = prefs.getInt('selectedSticker') ?? 12;
      _character = prefs.getString('character') ?? "emu";

      // 迁移旧的 "随机" 值
      if (_character == "随机") _character = kRandom;
      if (_selectedGroup == "随机") _selectedGroup = kRandom;

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

  // --- 4. 配置导入导出 ---
  Uri _saveAsUri() {
    final Map<String, dynamic> params = {
      'character': _character,
      'layers_json': jsonEncode(_layers.map((l) => l.toJson()).toList()),
    };

    if (_selectedSticker != -1) {
      params['character_index'] = _selectedSticker.toString();
    }

    return _apiBaseUrl.replace(queryParameters: params);
  }

  void _reloadFromUri(Uri uri) {
    final Map<String, List<String>> queryParams = uri.queryParametersAll;
    setState(() {
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

  // --- 5. 核心业务逻辑 ---
  void _debouncedCreateSticker() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _createSticker();
    });
  }

  Future<void> _createSticker() async {
    await _savePreferences();
    String char = _character != kRandom ? _character : "";
    if (PjskGenerator.groups.contains(char)) {
      final members = PjskGenerator.groupMembers[char]!;
      char = members[DateTime.now().millisecond % members.length];
    }
    char = PjskGenerator.characterMap[char] ?? char;
    if (_selectedSticker != -1) char = '$char$_selectedSticker';

    _byteData = await PjskGenerator.pjsk(layers: _layers, character: char);
    if (mounted) {
      setState(() {});
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

  void _resetPreferences() {
    setState(() {
      _character = "emu";
      _selectedCharacter = "emu";
      _selectedSticker = 12;
      _layers = [TextLayer(content: "わんだほーい")];
      _currentLayerId = _layers.first.id;
      _contextController.text = _currentLayer.content;
    });
    _createSticker();
  }

  void _addLayer() {
    setState(() {
      final newLayer = TextLayer(content: S.of(context).newLayerContent);
      _layers.add(newLayer);
      _currentLayerId = newLayer.id;
      _contextController.text = _currentLayer.content;
    });
    _createSticker();
  }

  void _removeLayer(int index) {
    if (_layers.length <= 1) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(S.of(context).atLeastOneLayer)));
      return;
    }

    final layerToRemove = _layers[index];
    final layerText = layerToRemove.content;
    final displayName =
        layerText.isEmpty
            ? S.of(context).layerDefault(index + 1)
            : (layerText.length > 10
                ? "${layerText.substring(0, 10)}..."
                : layerText);

    showAdaptiveDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).deleteLayer),
            content: Text(S.of(context).confirmDeleteLayer(displayName)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _layers.removeAt(index);
                    if (_currentLayerId == layerToRemove.id) {
                      _currentLayerId = _layers.first.id;
                    }
                    _contextController.text = _currentLayer.content;
                  });
                  _createSticker();
                  Navigator.pop(context);
                },
                child: Text(
                  S.of(context).confirmDelete,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  void _selectLayer(String id) {
    setState(() {
      _currentLayerId = id;
      _contextController.text = _currentLayer.content;
    });
  }

  void _showResetDialog() {
    showAdaptiveDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).resetAllParams),
            content: Text(S.of(context).resetAllParamsDesc),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  _resetPreferences();
                  Navigator.pop(context);
                },
                child: Text(
                  S.of(context).confirmReset,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ],
          ),
    );
  }

  void _pickColor() {
    Color selected = _currentLayer.customColor;
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(S.of(context).pickColor),
            content: SingleChildScrollView(
              child: ColorPicker(
                pickerColor: selected,
                enableAlpha: false,
                onColorChanged: (c) => selected = c,
                pickerAreaHeightPercent: 0.8,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(S.of(context).cancel),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _currentLayer.useCustomColor = true;
                    _currentLayer.customColor = selected;
                  });
                  _createSticker();
                  Navigator.pop(context);
                },
                child: Text(S.of(context).confirm),
              ),
            ],
          ),
    );
  }

  // --- 7. 角色选择器组件 ---
  Future<void> _selectCharacter1() async {
    if (_character == kRandom) {
      _selectedGroup = kRandom;
      _selectedCharacter = null;
    } else if (PjskGenerator.groups.contains(_character)) {
      _selectedGroup = _character;
      _selectedCharacter = PjskGenerator.groupMembers[_character]?.first;
    } else {
      String display = _character;
      if (PjskGenerator.characterList.contains(_character)) {
        try {
          display =
              PjskGenerator.characterMap.entries
                  .firstWhere((e) => e.value == _character)
                  .key;
        } catch (_) {}
      }
      _selectedCharacter = display;
      _selectedGroup = _findGroupForCharacter(display);
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setModalState) => _buildPickerContent(ctx, setModalState),
          ),
    );
  }

  Widget _buildPickerContent(BuildContext ctx, StateSetter setModalState) {
    final String? group =
        (_selectedGroup?.isNotEmpty ?? false) ? _selectedGroup : null;
    final String? character = _selectedCharacter;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (character != null && _characterKeys.containsKey(character)) {
        final key = _characterKeys[character];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.5,
          );
        }
      }
      if (character != null && _selectedSticker != -1) {
        final stickerKey =
            "${PjskGenerator.characterMap[character] ?? ""}_$_selectedSticker";
        final key = _stickerKeys[stickerKey];
        if (key?.currentContext != null) {
          Scrollable.ensureVisible(
            key!.currentContext!,
            duration: const Duration(milliseconds: 300),
            alignment: 0.3,
          );
        }
      }
    });

    return Container(
      height: MediaQuery.of(ctx).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(ctx).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(ctx).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          _buildGroupTabs(group, setModalState, ctx),
          const Divider(height: 16),
          if (group != null && group != kRandom) ...[
            _buildCharacterTabs(group, character, setModalState, ctx),
            const Divider(height: 16),
          ],
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                if (group == kRandom || group == null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: FilledButton.icon(
                        icon: const Icon(Icons.shuffle),
                        label: Text(S.of(ctx).confirmRandomCharacter),
                        onPressed: () {
                          setState(() => _character = kRandom);
                          _createSticker();
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  )
                else if (character != null) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        S.of(ctx).selectSticker,
                        style: Theme.of(ctx).textTheme.titleSmall,
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _character = character;
                            _selectedSticker = -1;
                          });
                          _createSticker();
                          Navigator.pop(ctx);
                        },
                        child: Text(S.of(ctx).random),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildStickerGrid(character, setModalState),
                ],
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupTabs(
    String? group,
    StateSetter setModalState,
    BuildContext ctx,
  ) {
    final List<String> all = [kRandom, ...PjskGenerator.groups];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _groupKeys[group ?? kRandom];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(
          key!.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.5,
        );
      }
    });

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children:
            all.map((g) {
              final isSelected =
                  (g == kRandom && group == null) || (g == group);
              final color =
                  g == kRandom
                      ? Theme.of(ctx).colorScheme.primary
                      : PjskGenerator.groupColor[g]!;
              return Padding(
                key: _groupKeys[g],
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(g == kRandom ? S.of(ctx).random : g),
                  selected: isSelected,
                  onSelected: (_) {
                    setModalState(() {
                      _selectedGroup = g;
                      if (g != kRandom) {
                        _selectedCharacter =
                            PjskGenerator.groupMembers[g]!.first;
                      }
                    });
                    setState(() {
                      _selectedGroup = g;
                      if (g != kRandom) {
                        _selectedCharacter =
                            PjskGenerator.groupMembers[g]!.first;
                      }
                    });
                  },
                  selectedColor: color.withValues(alpha: 0.3),
                  labelStyle: TextStyle(
                    color: isSelected ? color : null,
                    fontWeight: isSelected ? FontWeight.bold : null,
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }

  Widget _buildCharacterTabs(
    String group,
    String? character,
    StateSetter setModalState,
    BuildContext ctx,
  ) {
    final List<String> members = PjskGenerator.groupMembers[group] ?? [];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              label: Text(S.of(ctx).teamRandom),
              backgroundColor: (PjskGenerator.groupColor[group] ??
                      Theme.of(ctx).colorScheme.primary)
                  .withValues(alpha: 0.1),
              onPressed: () {
                setState(() {
                  _character = group;
                  _selectedSticker = -1;
                });
                _createSticker();
                Navigator.pop(ctx);
              },
            ),
          ),
          ...members.map((char) {
            final String internal = PjskGenerator.characterMap[char] ?? "";
            final isSelected = character == char || character == internal;
            final color = PjskGenerator.characterColor[internal] ?? Colors.grey;
            return Padding(
              key: _characterKeys[char],
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(char),
                selected: isSelected,
                selectedColor: color.withValues(alpha: 0.2),
                onSelected:
                    (_) => setModalState(() {
                      _selectedCharacter = char;
                      _selectedSticker = -1;
                    }),
                labelStyle: TextStyle(
                  color: isSelected ? color : null,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildStickerGrid(String character, StateSetter setModalState) {
    final String name = PjskGenerator.characterMap[character] ?? "miku";
    final List<String> stickers = PjskGenerator.characterStickers[name] ?? [];
    if (stickers.isEmpty)
      return Center(child: Text(S.of(context).stickerNotFound));

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final String file = stickers[index];
        final int stickerIndex =
            int.tryParse(file.replaceAll(name, '').split('.')[0]) ?? -1;
        final bool isSelected = _selectedSticker == stickerIndex;
        final key = _stickerKeys.putIfAbsent(
          "${name}_$stickerIndex",
          () => GlobalKey(),
        );

        return InkWell(
          key: key,
          onTap: () {
            setState(() {
              _character = character;
              _selectedSticker = stickerIndex;
            });
            _createSticker();
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              border:
                  isSelected
                      ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                      : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'assets/characters/$name/$file',
                fit: BoxFit.cover,
              ),
            ),
          ),
        );
      },
    );
  }

  // --- 8. UI 构建助手方法 ---
  Widget _buildPreviewArea(ColorScheme colorScheme) {
    return Expanded(
      flex: 2,
      child: Container(
        width: double.infinity,
        color: colorScheme.surfaceContainerHighest,
        child: Center(
          child:
              _byteData != null
                  ? GestureDetector(
                    onTap: _handleImageTap,
                    child: Card(
                      elevation: 8,
                      clipBehavior: Clip.antiAlias,
                      child: Image.memory(
                        key: ValueKey(_byteData.hashCode),
                        _byteData!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  )
                  : const CircularProgressIndicator(),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required String label,
    required double value,
    required double min,
    required double max,
    int divisions = 100,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(
                value.round().toString(),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildLayerBar(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            S.of(context).layerManagement,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(S.of(context).add),
                  onPressed: _addLayer,
                ),
              ),
              ...List.generate(_layers.length, (index) {
                final layer = _layers[index];
                final isSelected = _currentLayerId == layer.id;
                final text = layer.content;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onLongPress: () => _removeLayer(index),
                    child: ChoiceChip(
                      label: Text(
                        text.isEmpty
                            ? S.of(context).layerDefault(index + 1)
                            : (text.length > 8
                                ? "${text.substring(0, 8)}..."
                                : text),
                      ),
                      selected: isSelected,
                      onSelected: (_) => _selectLayer(layer.id),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // --- 9. 主构建方法 ---
  @override
  Widget build(BuildContext context) {
    final themeColor = _getThemeColor();
    final customTheme = Theme.of(context).copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor: themeColor,
        brightness: Theme.of(context).brightness,
      ),
    );

    final currentLayer = _currentLayer;

    return Theme(
      data: customTheme,
      child: Scaffold(
        appBar: AppBar(
          title: Text(S.of(context).appTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _showResetDialog,
              tooltip: S.of(context).reset,
            ),
            // IconButton(
            //   icon: const Icon(Icons.share),
            //   onPressed: _exportImportConfig,
            //   tooltip: "分享配置",
            // ),
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (ctx) => const SettingsPage()),
                );
                setState(() {});
                _createSticker();
              },
              tooltip: S.of(context).settings,
            ),
          ],
        ),
        body: Column(
          children: [
            _buildPreviewArea(customTheme.colorScheme),
            Expanded(
              flex: 3,
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  ListTile(
                    leading: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: themeColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.4),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    title: Text(S.of(context).characterSelect),
                    subtitle: Text(
                      _character == kRandom ? S.of(context).random : _character,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _selectCharacter1,
                  ),
                  const Divider(),
                  _buildLayerBar(customTheme.colorScheme),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      controller: _contextController,
                      decoration: InputDecoration(
                        labelText: S.of(context).editText,
                        prefixIcon: const Icon(Icons.text_fields),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _contextController.clear();
                            setState(() {
                              currentLayer.content = "";
                            });
                            _debouncedCreateSticker();
                          },
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      maxLines: null,
                      onChanged: (v) {
                        setState(() {
                          currentLayer.content = v;
                        });
                        _debouncedCreateSticker();
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildStyleExpansionTile(currentLayer),
                  _buildPositionExpansionTile(currentLayer),
                  _buildAdvancedExpansionTile(currentLayer),
                  const SizedBox(height: 64),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _handleImageTap,
          label: Text(S.of(context).exportImage),
          icon: const Icon(Icons.download),
        ),
      ),
    );
  }

  Widget _buildStyleExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.palette_outlined),
      title: Text(S.of(context).textStyle),
      initiallyExpanded: true,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<int>(
            key: ValueKey("font_${layer.id}_${PjskGenerator.fonts.length}"),
            decoration: InputDecoration(labelText: S.of(context).font),
            initialValue: layer.font.clamp(0, PjskGenerator.fonts.length - 1),
            items: [
              for (int i = 0; i < PjskGenerator.fonts.length; i++)
                DropdownMenuItem(
                  value: i,
                  child: Text(
                    PjskGenerator.fonts[i] == FontManager.systemFontName
                        ? S.of(context).systemDefault
                        : PjskGenerator.fonts[i],
                  ),
                ),
            ],
            onChanged: (v) {
              setState(() => layer.font = v!);
              _debouncedCreateSticker();
            },
          ),
        ),
        _buildSliderTile(
          label: S.of(context).fontSize,
          value: layer.fontSize,
          min: 0,
          max: 100,
          onChanged: (v) {
            setState(() => layer.fontSize = v);
            _debouncedCreateSticker();
          },
        ),
        _buildSliderTile(
          label: S.of(context).rotationAngle,
          value: layer.lean,
          min: -180,
          max: 180,
          divisions: 360,
          onChanged: (v) {
            setState(() => layer.lean = v);
            _debouncedCreateSticker();
          },
        ),
      ],
    );
  }

  Widget _buildPositionExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.open_with),
      title: Text(S.of(context).positionAdjust),
      children: [
        _buildSliderTile(
          label: S.of(context).xOffset,
          value: layer.pos.dx,
          min: -100,
          max: 300,
          divisions: 400,
          onChanged: (v) {
            setState(() => layer.pos = Offset(v, layer.pos.dy));
            _debouncedCreateSticker();
          },
        ),
        _buildSliderTile(
          label: S.of(context).yOffset,
          value: layer.pos.dy,
          min: -100,
          max: 300,
          divisions: 400,
          onChanged: (v) {
            setState(() => layer.pos = Offset(layer.pos.dx, v));
            _debouncedCreateSticker();
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedExpansionTile(TextLayer layer) {
    return ExpansionTile(
      leading: const Icon(Icons.tune),
      title: Text(S.of(context).advancedStyle),
      children: [
        _buildSliderTile(
          label: S.of(context).strokeWidth,
          value: layer.edgeSize.toDouble(),
          min: 0,
          max: 20,
          divisions: 20,
          onChanged: (v) {
            setState(() => layer.edgeSize = v.round());
            _debouncedCreateSticker();
          },
        ),
        SwitchListTile(
          title: Text(S.of(context).customColor),
          subtitle: Text(S.of(context).customColorHint),
          secondary: const Icon(Icons.format_color_fill),
          value: layer.useCustomColor,
          onChanged: (v) {
            setState(() => layer.useCustomColor = v);
            _debouncedCreateSticker();
          },
        ),
        ListTile(
          enabled: layer.useCustomColor,
          leading: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: layer.customColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
          ),
          title: Text(S.of(context).textColor),
          trailing: Text(
            '#${layer.customColor.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
          onTap: _pickColor,
        ),
      ],
    );
  }
}
