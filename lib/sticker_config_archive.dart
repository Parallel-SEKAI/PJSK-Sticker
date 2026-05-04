import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'sticker.dart';

/// PJSK Sticker 配置归档工具
///
/// 提供 ZIP+JSON 格式的贴纸配置导出/导入功能
///
/// 格式规范：
/// - 文件扩展名：`.pjsksticker.zip`
/// - ZIP 根目录包含 `metadata.json`
/// - 每个贴纸在 `stickers/<stickerId>/sticker.json`
/// - 自定义底图保存为 `stickers/<stickerId>/background.png`
class StickerConfigArchive {
  static const String kMetadataSchemaUrl =
      'https://raw.githubusercontent.com/Parallel-SEKAI/PJSK-Sticker/main/schemas/pjsk-sticker-pack-v1.schema.json';
  static const String kStickerSchemaUrl =
      'https://raw.githubusercontent.com/Parallel-SEKAI/PJSK-Sticker/main/schemas/pjsk-sticker-v1.schema.json';
  static const String kVersion = '1.0.0';
  static const String kMetadataFile = 'metadata.json';
  static const String kStickersDir = 'stickers';
  static const String kStickerJsonFile = 'sticker.json';
  static const String kBackgroundFile = 'background.png';

  /// 导出单个贴纸配置为 ZIP 字节流
  ///
  /// 参数：
  /// - [packName]: 贴纸包名称
  /// - [stickerId]: 贴纸 ID（用于文件夹命名）
  /// - [stickerName]: 贴纸名称（可选）
  /// - [characterId]: 角色 ID（如 "emu"）
  /// - [imageId]: 底图编号（如 14）
  /// - [layers]: 文本图层列表
  /// - [customBackgroundBytes]: 自定义底图字节流（可选）
  /// - [customBackgroundFilename]: 自定义底图文件名（可选，默认 "background.png"）
  static Uint8List exportSingleSticker({
    required String packName,
    required String stickerId,
    String? stickerName,
    required String characterId,
    required int imageId,
    required List<TextLayer> layers,
    Uint8List? customBackgroundBytes,
    String? customBackgroundFilename,
  }) {
    final archive = Archive();

    // 1. 创建 metadata.json
    final metadata = {
      '\$schema': kMetadataSchemaUrl,
      'version': kVersion,
      'data': {
        'packName': packName,
        'stickers': [
          {'id': stickerId, 'name': stickerName},
        ],
      },
    };
    final metadataJson = _encodeJsonPretty(metadata);
    archive.addFile(
      ArchiveFile(kMetadataFile, metadataJson.length, metadataJson),
    );

    // 2. 创建 stickers/<stickerId>/sticker.json
    final stickerDir = '$kStickersDir/$stickerId';
    final stickerConfig = _buildStickerConfig(
      characterId: characterId,
      imageId: imageId,
      layers: layers,
      hasCustomBackground: customBackgroundBytes != null,
      customBackgroundFilename: customBackgroundFilename,
    );
    final stickerJson = _encodeJsonPretty(stickerConfig);
    archive.addFile(
      ArchiveFile(
        '$stickerDir/$kStickerJsonFile',
        stickerJson.length,
        stickerJson,
      ),
    );

    // 3. 如果有自定义底图，保存到 stickers/<stickerId>/background.png
    if (customBackgroundBytes != null) {
      final filename = customBackgroundFilename ?? kBackgroundFile;
      archive.addFile(
        ArchiveFile(
          '$stickerDir/$filename',
          customBackgroundBytes.length,
          customBackgroundBytes,
        ),
      );
    }

    // 4. 编码为 ZIP
    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  /// 从 ZIP 字节流导入贴纸配置
  ///
  /// 返回：
  /// - `packName`: 贴纸包名称
  /// - `stickers`: 贴纸列表，每个包含：
  ///   - `id`: 贴纸 ID
  ///   - `name`: 贴纸名称
  ///   - `characterId`: 角色 ID（用于默认颜色）
  ///   - `imageId`: 底图编号（如果是内置底图）
  ///   - `layers`: 文本图层列表
  ///   - `customBackgroundBytes`: 自定义底图字节流（如果有）
  ///   - `customBackgroundFilename`: 自定义底图文件名（如果有）
  ///
  /// 抛出异常：
  /// - 如果 ZIP 格式无效
  /// - 如果缺少必需文件
  /// - 如果 JSON 格式无效
  /// - 如果路径不安全
  static Map<String, dynamic> importFromZip(Uint8List zipBytes) {
    // 1. 解码 ZIP
    final archive = ZipDecoder().decodeBytes(zipBytes);

    // 2. 读取 metadata.json
    final metadataFile = archive.findFile(kMetadataFile);
    if (metadataFile == null) {
      throw Exception('Missing $kMetadataFile in archive');
    }
    final metadataJson = utf8.decode(metadataFile.content as List<int>);
    final metadata = jsonDecode(metadataJson) as Map<String, dynamic>;

    // 3. 验证 metadata 结构
    _validateMetadata(metadata);

    final data = metadata['data'] as Map<String, dynamic>;
    final packName = data['packName'] as String;
    final stickersMeta = data['stickers'] as List<dynamic>;

    // 4. 解析每个贴纸
    final stickers = <Map<String, dynamic>>[];
    for (final stickerMeta in stickersMeta) {
      final stickerId = stickerMeta['id'] as String;
      final stickerName = stickerMeta['name'] as String?;

      // 读取 sticker.json
      final stickerDir = '$kStickersDir/$stickerId';
      final stickerJsonPath = '$stickerDir/$kStickerJsonFile';
      final stickerFile = archive.findFile(stickerJsonPath);
      if (stickerFile == null) {
        throw Exception('Missing $stickerJsonPath in archive');
      }

      final stickerJson = utf8.decode(stickerFile.content as List<int>);
      final stickerConfig = jsonDecode(stickerJson) as Map<String, dynamic>;

      // 验证 sticker.json 结构
      _validateStickerConfig(stickerConfig);

      final stickerData = stickerConfig['data'] as Map<String, dynamic>;
      final characterId = stickerData['characterId'] as String;
      final background = stickerData['background'] as Map<String, dynamic>;
      final layersJson = stickerData['layers'] as List<dynamic>;

      // 解析背景
      int? imageId;
      Uint8List? customBackgroundBytes;
      String? customBackgroundFilename;

      final bgType = background['type'] as String;
      if (bgType == 'asset') {
        imageId = background['imageId'] as int;
      } else if (bgType == 'custom') {
        final bgFile = background['file'] as String;
        // 安全检查：禁止路径遍历
        _validateFilePath(bgFile);
        final bgPath = '$stickerDir/$bgFile';
        final bgArchiveFile = archive.findFile(bgPath);
        if (bgArchiveFile == null) {
          throw Exception('Missing custom background file: $bgPath');
        }
        customBackgroundBytes = Uint8List.fromList(
          bgArchiveFile.content as List<int>,
        );
        customBackgroundFilename = bgFile;
      } else {
        throw Exception('Unknown background type: $bgType');
      }

      // 解析图层
      final layers =
          layersJson.map((layerJson) {
            return _parseLayer(layerJson as Map<String, dynamic>);
          }).toList();

      stickers.add({
        'id': stickerId,
        'name': stickerName,
        'characterId': characterId,
        'imageId': imageId,
        'layers': layers,
        'customBackgroundBytes': customBackgroundBytes,
        'customBackgroundFilename': customBackgroundFilename,
      });
    }

    return {'packName': packName, 'stickers': stickers};
  }

  /// 构建 sticker.json 配置
  static Map<String, dynamic> _buildStickerConfig({
    required String characterId,
    required int imageId,
    required List<TextLayer> layers,
    required bool hasCustomBackground,
    String? customBackgroundFilename,
  }) {
    final background =
        hasCustomBackground
            ? {
              'type': 'custom',
              'file': customBackgroundFilename ?? kBackgroundFile,
            }
            : {'type': 'asset', 'characterId': characterId, 'imageId': imageId};

    return {
      '\$schema': kStickerSchemaUrl,
      'version': kVersion,
      'data': {
        'characterId': characterId,
        'background': background,
        'layers': layers.map(_serializeLayer).toList(),
      },
    };
  }

  /// 序列化图层为可读 JSON
  static Map<String, dynamic> _serializeLayer(TextLayer layer) {
    return {
      'id': layer.id,
      'content': layer.content,
      'position': {'x': layer.pos.dx, 'y': layer.pos.dy},
      'rotation': layer.lean,
      'fontSize': layer.fontSize,
      'strokeWidth': layer.edgeSize,
      'fontIndex': layer.font,
      'color':
          layer.useCustomColor
              ? {'custom': true, 'value': _colorToHex(layer.customColor)}
              : {'custom': false},
      'opacity': layer.opacity,
      'visible': layer.visible,
      'locked': layer.locked,
      'bend': {'curvature': layer.bendCurvature, 'spacing': layer.bendSpacing},
    };
  }

  /// 解析图层 JSON 为 TextLayer
  static TextLayer _parseLayer(Map<String, dynamic> json) {
    final position = json['position'] as Map<String, dynamic>;
    final color = json['color'] as Map<String, dynamic>;
    final bend = json['bend'] as Map<String, dynamic>? ?? {};

    return TextLayer(
      id: json['id'] as String,
      content: json['content'] as String,
      pos: Offset(
        (position['x'] as num).toDouble(),
        (position['y'] as num).toDouble(),
      ),
      lean: (json['rotation'] as num).toDouble(),
      fontSize: (json['fontSize'] as num).toDouble(),
      edgeSize: json['strokeWidth'] as int,
      font: json['fontIndex'] as int,
      useCustomColor: color['custom'] as bool,
      customColor:
          color['custom'] == true
              ? _hexToColor(color['value'] as String)
              : const Color(0xFFDDAACC),
      opacity: (json['opacity'] as num).toDouble(),
      visible: json['visible'] as bool,
      locked: json['locked'] as bool,
      bendCurvature: (bend['curvature'] as num?)?.toDouble() ?? 0.0,
      bendSpacing: (bend['spacing'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// 验证 metadata.json 结构
  static void _validateMetadata(Map<String, dynamic> metadata) {
    if (!metadata.containsKey('\$schema')) {
      throw Exception('Missing \$schema in metadata');
    }
    if (!metadata.containsKey('version')) {
      throw Exception('Missing version in metadata');
    }
    if (!metadata.containsKey('data')) {
      throw Exception('Missing data in metadata');
    }

    final data = metadata['data'] as Map<String, dynamic>;
    if (!data.containsKey('packName')) {
      throw Exception('Missing packName in metadata.data');
    }
    if (!data.containsKey('stickers')) {
      throw Exception('Missing stickers in metadata.data');
    }
  }

  /// 验证 sticker.json 结构
  static void _validateStickerConfig(Map<String, dynamic> config) {
    if (!config.containsKey('\$schema')) {
      throw Exception('Missing \$schema in sticker config');
    }
    if (!config.containsKey('version')) {
      throw Exception('Missing version in sticker config');
    }
    if (!config.containsKey('data')) {
      throw Exception('Missing data in sticker config');
    }

    final data = config['data'] as Map<String, dynamic>;
    if (!data.containsKey('background')) {
      throw Exception('Missing background in sticker config');
    }
    if (!data.containsKey('layers')) {
      throw Exception('Missing layers in sticker config');
    }
  }

  /// 验证文件路径安全性
  ///
  /// 禁止：
  /// - 路径遍历（`../`）
  /// - 绝对路径（以 `/` 开头）
  /// - 空路径
  static void _validateFilePath(String path) {
    if (path.isEmpty) {
      throw Exception('Empty file path');
    }
    if (path.startsWith('/')) {
      throw Exception('Absolute path not allowed: $path');
    }
    if (path.contains('../')) {
      throw Exception('Path traversal not allowed: $path');
    }
    // 额外检查：Windows 绝对路径
    if (path.contains(':')) {
      throw Exception('Absolute path not allowed: $path');
    }
  }

  /// 将 Color 转换为十六进制字符串（#RRGGBB 或 #AARRGGBB）
  static String _colorToHex(Color color) {
    final a = (color.a * 255.0).round().clamp(0, 255);
    final r = (color.r * 255.0).round().clamp(0, 255);
    final g = (color.g * 255.0).round().clamp(0, 255);
    final b = (color.b * 255.0).round().clamp(0, 255);

    if (a == 255) {
      return '#${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
    } else {
      return '#${a.toRadixString(16).padLeft(2, '0')}'
              '${r.toRadixString(16).padLeft(2, '0')}'
              '${g.toRadixString(16).padLeft(2, '0')}'
              '${b.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();
    }
  }

  /// 将十六进制字符串转换为 Color
  static Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // 添加完全不透明的 alpha
    }
    return Color(int.parse(hex, radix: 16));
  }

  /// 编码 JSON 为格式化字符串
  static Uint8List _encodeJsonPretty(Map<String, dynamic> json) {
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = encoder.convert(json);
    return Uint8List.fromList(utf8.encode(jsonString));
  }
}
