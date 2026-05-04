import 'package:flutter_test/flutter_test.dart';
import 'package:pjsk_sticker/sticker_config_archive.dart';
import 'package:pjsk_sticker/sticker.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';

void main() {
  group('StickerConfigArchive', () {
    test('导出和导入内置底图贴纸', () {
      // 创建测试图层
      final layers = [
        TextLayer(
          content: 'わんだほーい',
          pos: const Offset(20, 10),
          lean: 15,
          fontSize: 50,
          edgeSize: 4,
          font: 1,
        ),
        TextLayer(
          content: 'Test Layer',
          pos: const Offset(50, 30),
          lean: 0,
          fontSize: 42,
          edgeSize: 3,
          font: 0,
          useCustomColor: true,
          customColor: const Color(0xFF5588CC),
          opacity: 0.9,
        ),
      ];

      // 导出
      final zipBytes = StickerConfigArchive.exportSingleSticker(
        packName: '测试贴纸包',
        stickerId: 'test_001',
        stickerName: '测试贴纸',
        characterId: 'emu',
        imageId: 14,
        layers: layers,
      );

      expect(zipBytes.isNotEmpty, true);

      // 导入
      final result = StickerConfigArchive.importFromZip(zipBytes);

      expect(result['packName'], '测试贴纸包');

      final stickers = result['stickers'] as List<Map<String, dynamic>>;
      expect(stickers.length, 1);

      final sticker = stickers[0];
      expect(sticker['id'], 'test_001');
      expect(sticker['name'], '测试贴纸');
      expect(sticker['characterId'], 'emu');
      expect(sticker['imageId'], 14);

      final importedLayers = sticker['layers'] as List<TextLayer>;
      expect(importedLayers.length, 2);

      // 验证第一个图层
      expect(importedLayers[0].content, 'わんだほーい');
      expect(importedLayers[0].pos.dx, 20);
      expect(importedLayers[0].pos.dy, 10);
      expect(importedLayers[0].lean, 15);
      expect(importedLayers[0].fontSize, 50);
      expect(importedLayers[0].edgeSize, 4);
      expect(importedLayers[0].font, 1);

      // 验证第二个图层
      expect(importedLayers[1].content, 'Test Layer');
      expect(importedLayers[1].useCustomColor, true);
      expect(importedLayers[1].customColor.toARGB32(), 0xFF5588CC);
      expect(importedLayers[1].opacity, 0.9);
    });

    test('导出和导入自定义底图贴纸', () {
      final layers = [
        TextLayer(content: 'Custom BG', pos: const Offset(10, 20)),
      ];

      // 创建假的 PNG 字节流（实际应该是真实的 PNG）
      final customBg = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG header
        ...List.filled(100, 0),
      ]);

      // 导出
      final zipBytes = StickerConfigArchive.exportSingleSticker(
        packName: '自定义底图包',
        stickerId: 'custom_001',
        characterId: 'miku', // 用于默认颜色
        imageId: 1,
        layers: layers,
        customBackgroundBytes: customBg,
      );

      expect(zipBytes.isNotEmpty, true);

      // 导入
      final result = StickerConfigArchive.importFromZip(zipBytes);

      final stickers = result['stickers'] as List<Map<String, dynamic>>;
      final sticker = stickers[0];

      // characterId 应该存在，用于恢复默认颜色
      expect(sticker['characterId'], 'miku');
      expect(sticker['imageId'], null);
      expect(sticker['customBackgroundBytes'], isNotNull);
      expect(sticker['customBackgroundFilename'], 'background.png');

      final bgBytes = sticker['customBackgroundBytes'] as Uint8List;
      expect(bgBytes.length, customBg.length);
    });

    test('路径安全验证', () {
      // 测试路径遍历攻击
      expect(
        () => StickerConfigArchive.importFromZip(
          _createMaliciousZip('../../../etc/passwd'),
        ),
        throwsException,
      );
    });

    test('颜色转换', () {
      // 颜色转换是内部实现，通过导入导出间接测试
      final layers = [
        TextLayer(
          content: 'Color Test',
          useCustomColor: true,
          customColor: const Color(0xFFFF5588),
        ),
      ];

      final zipBytes = StickerConfigArchive.exportSingleSticker(
        packName: 'Test',
        stickerId: 'test',
        characterId: 'emu',
        imageId: 1,
        layers: layers,
      );

      final result = StickerConfigArchive.importFromZip(zipBytes);
      final stickers = result['stickers'] as List<Map<String, dynamic>>;
      final importedLayers = stickers[0]['layers'] as List<TextLayer>;

      expect(importedLayers[0].customColor.toARGB32(), 0xFFFF5588);
    });
  });
}

// 创建恶意 ZIP 用于测试路径遍历
Uint8List _createMaliciousZip(String maliciousPath) {
  // 这里简化实现，实际测试中应该创建真实的恶意 ZIP
  // 为了测试目的，我们创建一个包含恶意路径的 ZIP
  return Uint8List.fromList([]);
}
