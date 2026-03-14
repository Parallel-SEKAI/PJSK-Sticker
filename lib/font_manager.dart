import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FontInfo {
  final String name;
  final String url;
  String? filePath;

  FontInfo({required this.name, required this.url, this.filePath});

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'filePath': filePath,
  };

  factory FontInfo.fromJson(Map<String, dynamic> json) => FontInfo(
    name: json['name'] ?? '',
    url: json['url'] ?? '',
    filePath: json['filePath'],
  );
}

class FontManager {
  FontManager._();
  static final FontManager instance = FontManager._();

  List<FontInfo> _fonts = [];
  List<FontInfo> get fonts => List.unmodifiable(_fonts);

  bool get hasFonts => _fonts.any((f) => f.filePath != null);

  static const String systemFontName = '__system__';

  final Set<String> _registeredFonts = {};

  bool isFontRegistered(String name) => _registeredFonts.contains(name);

  List<String> get availableFontNames => [
    systemFontName,
    ..._fonts.where((f) => f.filePath != null).map((f) => f.name),
  ];

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final String? json = prefs.getString('font_list');
    if (json != null && json.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(json);
        _fonts = list.map((e) => FontInfo.fromJson(e)).toList();
      } catch (e) {
        if (kDebugMode) {
          print('Error loading font list: $e');
        }
        _fonts = [];
      }
    }
    // 验证本地文件是否存在且格式有效
    for (var font in _fonts) {
      if (font.filePath != null) {
        final file = File(font.filePath!);
        if (!file.existsSync()) {
          font.filePath = null;
        } else {
          try {
            final head = await file.openRead(0, 4).first;
            if (!_isValidFontHeader(head)) {
              if (kDebugMode) {
                print(
                  '[FontManager] init: ${font.name} is not a valid TTF/OTF, removing',
                );
              }
              await file.delete();
              font.filePath = null;
            }
          } catch (_) {
            font.filePath = null;
          }
        }
      }
    }
    await _saveFontList();

    // 启动时注册所有已下载字体到 Flutter 引擎
    for (var font in _fonts) {
      if (font.filePath != null) {
        await registerFont(font.name);
      }
    }
  }

  Future<Directory> _getFontDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final fontDir = Directory('${dir.path}/fonts');
    if (!fontDir.existsSync()) {
      fontDir.createSync(recursive: true);
    }
    return fontDir;
  }

  static const _supportedExts = ['.ttf', '.otf'];

  static bool _isValidFontHeader(List<int> head) {
    if (head.length < 4) return false;
    final isTtf =
        (head[0] == 0x00 &&
            head[1] == 0x01 &&
            head[2] == 0x00 &&
            head[3] == 0x00) ||
        (head[0] == 0x74 &&
            head[1] == 0x72 &&
            head[2] == 0x75 &&
            head[3] == 0x65);
    final isOtf =
        head[0] == 0x4F &&
        head[1] == 0x54 &&
        head[2] == 0x54 &&
        head[3] == 0x4F;
    return isTtf || isOtf;
  }

  Future<void> downloadFont(String name, String url) async {
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    String ext = '';
    if (pathSegments.isNotEmpty) {
      final lastSegment = pathSegments.last.toLowerCase();
      if (lastSegment.contains('.')) {
        ext = '.${lastSegment.split('.').last}';
      }
    }
    if (ext.isNotEmpty && !_supportedExts.contains(ext)) {
      throw Exception(
        'Unsupported font format ($ext), only .ttf and .otf are supported',
      );
    }
    if (ext.isEmpty) {
      ext = '.ttf';
    }

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final bytes = response.bodyBytes;
    if (!_isValidFontHeader(bytes)) {
      throw Exception('Invalid font file (not TTF/OTF, possibly woff/woff2)');
    }

    final fontDir = await _getFontDir();
    final file = File('${fontDir.path}/$name$ext');
    await file.writeAsBytes(bytes);

    final existing = _fonts.indexWhere((f) => f.name == name);
    if (existing != -1) {
      _fonts[existing] = FontInfo(name: name, url: url, filePath: file.path);
    } else {
      _fonts.add(FontInfo(name: name, url: url, filePath: file.path));
    }

    _registeredFonts.remove(name);
    await registerFont(name);
    await _saveFontList();
  }

  Future<void> deleteFont(String name) async {
    final index = _fonts.indexWhere((f) => f.name == name);
    if (index == -1) return;

    final font = _fonts[index];
    if (font.filePath != null) {
      final file = File(font.filePath!);
      if (file.existsSync()) {
        await file.delete();
      }
    }
    _fonts.removeAt(index);
    _registeredFonts.remove(name);
    await _saveFontList();
  }

  Future<Uint8List?> loadFontBytes(String name) async {
    final font = _fonts.cast<FontInfo?>().firstWhere(
      (f) => f!.name == name,
      orElse: () => null,
    );
    if (font?.filePath == null) {
      return null;
    }
    final file = File(font!.filePath!);
    if (!file.existsSync()) {
      return null;
    }
    return file.readAsBytes();
  }

  bool isFontDownloaded(String name) {
    final font = _fonts.cast<FontInfo?>().firstWhere(
      (f) => f!.name == name,
      orElse: () => null,
    );
    return font?.filePath != null;
  }

  Future<void> registerFont(String name) async {
    if (_registeredFonts.contains(name)) return;
    final bytes = await loadFontBytes(name);
    if (bytes == null || bytes.isEmpty) {
      return;
    }
    try {
      final clean = Uint8List.fromList(bytes);
      final loader = FontLoader(name)
        ..addFont(Future.value(ByteData.view(clean.buffer)));
      await loader.load();
      _registeredFonts.add(name);
    } catch (e) {
      if (kDebugMode) {
        print('[FontManager] registerFont($name): FAILED - $e');
      }
    }
  }

  Future<void> _saveFontList() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'font_list',
      jsonEncode(_fonts.map((f) => f.toJson()).toList()),
    );
  }
}
