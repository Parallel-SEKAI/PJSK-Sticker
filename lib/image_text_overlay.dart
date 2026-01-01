import "dart:math";
import "dart:ui" as ui;
import "package:flutter/material.dart";
import "package:flutter/services.dart";

class ImageTextOverlay {
  static Future<Uint8List> generateStickerFromBytes({
    required Uint8List imageBytes,
    required String content,
    required String fontFamilyName,
    required Uint8List fontBytes,
    Offset pos = const Offset(20, 10),
    double lean = 15,
    double fontSize = 50,
    int edgeSize = 4,
    required Color color,
  }) async {
    final bgImage = await _decodeImageFromBytes(imageBytes);

    final textPainter = await _createTextPainter(
      content: content,
      fontSize: fontSize,
      edgeSize: edgeSize,
      fontFamilyName: fontFamilyName,
      fontBytes: fontBytes,
      color: color,
    );

    final image = await _compositeImages(bgImage, textPainter, pos, lean);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static Future<ui.Image> _decodeImageFromBytes(Uint8List imageData) async {
    return decodeImageFromList(Uint8List.view(imageData.buffer));
  }

  static Future<void> _loadFontFromBytes(Uint8List fontBytes, String fontFamilyName) async {
    final fontProvider = FontLoader(fontFamilyName)
      ..addFont(Future.value(ByteData.view(fontBytes.buffer)));
    await fontProvider.load();
  }

  static Future<TextPainter> _createTextPainter({
    required String content,
    required double fontSize,
    required int edgeSize,
    required String fontFamilyName,
    required Uint8List fontBytes,
    required Color color,
  }) async {
    await _loadFontFromBytes(fontBytes, fontFamilyName);

    final textStyle = TextStyle(
      fontFamily: fontFamilyName,
      fontSize: fontSize,
      color: color,
      shadows:
          getOffsets(360)
              .map(
                (offset) => Shadow(
                  color: Colors.white,
                  offset: offset * edgeSize.toDouble(),
                  blurRadius: 0,
                ),
              )
              .toList(),
    );

    final lines = content.split("\n");
    double maxWidth = 0;

    for (final line in lines) {
      final textSpan = TextSpan(text: line, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      maxWidth = maxWidth > textPainter.width ? maxWidth : textPainter.width;
    }

    final painter = TextPainter(
      text: TextSpan(text: content, style: textStyle),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);

    return painter;
  }

  static Future<ui.Image> _compositeImages(
    ui.Image bgImage,
    TextPainter textPainter,
    Offset position,
    double lean,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    canvas.drawImage(bgImage, Offset.zero, Paint());

    canvas.save();

    final center = Offset(textPainter.width / 2, textPainter.height / 2);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-lean * pi / 180);

    textPainter.paint(
      canvas,
      Offset(-textPainter.width / 2, -textPainter.height / 2) + position,
    );

    canvas.restore();

    final picture = recorder.endRecording();
    return await picture.toImage(bgImage.width, bgImage.height);
  }

  static List<Offset> getOffsets(int precision) {
    assert(precision > 0);
    List<Offset> offsets = [];
    for (int i = 0; i < precision; i++) {
      final angle = 2 * pi * i / precision;
      final x = cos(angle);
      final y = sin(angle);
      offsets.add(Offset(x, y));
    }
    return offsets;
  }
}
