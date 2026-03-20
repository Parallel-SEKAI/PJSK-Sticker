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

part 'sticker/sticker_page_config.dart';
part 'sticker/sticker_page_logic.dart';
part 'sticker/sticker_page_layers.dart';
part 'sticker/sticker_page_picker.dart';
part 'sticker/sticker_page_sections.dart';

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

  void _update(VoidCallback fn) => setState(fn);

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
}
