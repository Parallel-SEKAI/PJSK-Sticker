import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:pjsk_sticker/pages/about.dart';
import 'package:pjsk_sticker/sticker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_sticker/web_utils.dart'
    if (dart.library.io) 'package:pjsk_sticker/web_utils_stub.dart';

class StickerPage extends StatefulWidget {
  const StickerPage({super.key});
  @override
  State<StickerPage> createState() => _StickerPageState();
}

class _StickerPageState extends State<StickerPage> {
  static final Uri apiBaseUrl = Uri.parse(
    "https://api.parallel-sekai.org/pjsk-sticker",
  );
  final RegExp urlReg = RegExp(
    apiBaseUrl.toString() + r"[\w\-._~:/?#[\]@!$&\'()*+,;=%]+",
    caseSensitive: false,
  );
  final TextEditingController _contextController = TextEditingController(
    text: "わんだほーい",
  );
  String? _selectedGroup;
  String? _selectedCharacter = "emu";
  int _selectedSticker = 12;
  bool _selected = false;
  String _character = "emu";
  Uint8List? _byteData;
  int _font = 0;
  Offset _pos = Offset(20, 10);
  double _fontSize = 42;
  int _edgeSize = 4;
  double _lean = 15;
  bool _moreSettingsEnabled = false;
  Color _moreSettingsColor = Color(0xFFDDAACC);
  // int _time = 0;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  // 从SharedPreferences加载参数
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _contextController.text = prefs.getString('content') ?? "わんだほーい";
      _selectedGroup = prefs.getString('selectedGroup');
      _selectedCharacter = prefs.getString('selectedCharacter') ?? "emu";
      _selectedSticker = prefs.getInt('selectedSticker') ?? 12;
      _selected = prefs.getBool('selected') ?? false;
      _character = prefs.getString('character') ?? "emu";
      _font = prefs.getInt('font') ?? 0;
      _pos = Offset(
        prefs.getDouble('posX') ?? 20,
        prefs.getDouble('posY') ?? 10,
      );
      _fontSize = prefs.getDouble('fontSize') ?? 42;
      _edgeSize = prefs.getInt('edgeSize') ?? 4;
      _lean = prefs.getDouble('lean') ?? 15;
    });
    _createSticker();
  }

  // 保存参数到SharedPreferences
  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('content', _contextController.text);
    await prefs.setString('selectedGroup', _selectedGroup ?? '');
    await prefs.setString('selectedCharacter', _selectedCharacter ?? 'emu');
    await prefs.setInt('selectedSticker', _selectedSticker);
    await prefs.setBool('selected', _selected);
    await prefs.setString('character', _character);
    await prefs.setInt('font', _font);
    await prefs.setDouble('posX', _pos.dx);
    await prefs.setDouble('posY', _pos.dy);
    await prefs.setDouble('fontSize', _fontSize);
    await prefs.setInt('edgeSize', _edgeSize);
    await prefs.setDouble('lean', _lean);
  }

  Uri _saveAsUri() {
    final Map<String, dynamic> queryParameters = {
      'character': _character,
      'text': _contextController.text,
      'font_size': _fontSize.round().toString(),
      'stroke_width': _edgeSize.toString(),
      'rotation_angle': _lean.round().toString(),
    };

    if (_selectedSticker != -1) {
      queryParameters['character_index'] = _selectedSticker.toString();
    }
    // position is a repeated parameter, so we need to add it separately
    final List<String> positionList = [
      _pos.dx.round().toString(),
      _pos.dy.round().toString(),
    ];
    final List<String> textColorList = [
      (_moreSettingsColor.r * 256.0).floor().toString(),
      (_moreSettingsColor.g * 256.0).floor().toString(),
      (_moreSettingsColor.b * 256.0).floor().toString(),
    ];

    // font_path is derived from _font index
    if (_font >= 0 && _font < PjskGenerator.fonts.length) {
      queryParameters['font_path'] = PjskGenerator.fonts[_font];
    }

    // Build URI with all parameters
    final Uri uri = apiBaseUrl.replace(
      queryParameters: {
        ...queryParameters.map((key, value) => MapEntry(key, value.toString())),
        'position': positionList,
        if (_moreSettingsEnabled) 'text_color': textColorList,
      },
    );

    return uri;
  }

  void _reloadFromUri(Uri uri) async {
    final Map<String, List<String>> queryParams = uri.queryParametersAll;
    setState(() {
      _contextController.text =
          queryParams['text']?.first ?? _contextController.text;
      _character = queryParams['character']?.first ?? _character;
      _selectedSticker =
          int.tryParse(queryParams['character_index']?.first ?? '') ??
          _selectedSticker;

      final List<String>? positions = queryParams['position'];
      if (positions != null && positions.length == 2) {
        _pos = Offset(
          double.tryParse(positions[0]) ?? _pos.dx,
          double.tryParse(positions[1]) ?? _pos.dy,
        );
      }

      _fontSize =
          double.tryParse(queryParams['font_size']?.first ?? '') ?? _fontSize;
      _edgeSize =
          int.tryParse(queryParams['stroke_width']?.first ?? '') ?? _edgeSize;
      _lean =
          double.tryParse(queryParams['rotation_angle']?.first ?? '') ?? _lean;

      final List<String>? textColor = queryParams['text_color'];
      if (textColor != null && textColor.length == 3) {
        _moreSettingsEnabled = true;
        _moreSettingsColor = Color.fromARGB(
          255,
          int.tryParse(textColor[0]) ?? (_moreSettingsColor.r * 256.0).floor(),
          int.tryParse(textColor[1]) ?? (_moreSettingsColor.g * 256.0).floor(),
          int.tryParse(textColor[2]) ?? (_moreSettingsColor.b * 256.0).floor(),
        );
      } else {
        _moreSettingsEnabled = false;
      }

      final String? fontPath = queryParams['font_path']?.first;
      if (fontPath != null) {
        final int fontIndex = PjskGenerator.fonts.indexOf(fontPath);
        if (fontIndex != -1) {
          _font = fontIndex;
        }
      }
    });
    _createSticker();
  }

  Future<void> _exportImportConfig() async {
    if (mounted) {
      final TextEditingController configController = TextEditingController(
        text: _saveAsUri().toString(),
      );
      showAdaptiveDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("导出/导入配置"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("导出图片请直接点击图片，点击下方按钮导出配置，或粘贴配置后点击导入"),
                SizedBox(height: 8),
                TextField(
                  controller: configController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: "粘贴配置内容…",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              if (Platform.isAndroid)
                TextButton(
                  onPressed: () async {
                    await SharePlus.instance.share(
                      ShareParams(
                        text:
                            '分享表情包: ${configController.text}\n使用 https://github.com/Parallel-SEKAI/PJSK-Sticker/ 制作',
                        title: "分享 PJSK Sticker 配置",
                      ),
                    );
                  },
                  child: Text("分享"),
                ),
              TextButton(
                onPressed: () {
                  configController.text = _saveAsUri().toString();
                  Clipboard.setData(ClipboardData(text: configController.text));
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text("已复制")));
                },
                child: Text("复制"),
              ),
              TextButton(
                onPressed: () async {
                  // 使用正则表达式从剪贴板文本中提取第一个合法的 URL
                  final ClipboardData? raw = await Clipboard.getData(
                    Clipboard.kTextPlain,
                  );
                  final String? text = raw?.text;
                  if (text != null) {
                    final match = urlReg.firstMatch(text);
                    if (match != null) {
                      configController.text = match.group(0)!;
                    }
                  }
                },
                child: Text("粘贴"),
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
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text("配置格式错误")));
                    }
                  }
                },
                child: Text("导入"),
              ),
              // TextButton(
              //   onPressed: () => Navigator.pop(context),
              //   child: Text("取消"),
              // ),
            ],
          );
        },
      );
    }
  }

  Future<void> _createSticker() async {
    // 先保存参数
    await _savePreferences();

    String content = _contextController.text;
    String character = _character != "随机" ? _character : "";
    if (PjskGenerator.groups.contains(character)) {
      final String group = character;
      final List<String> members = PjskGenerator.groupMembers[group]!;
      character = members[DateTime.now().millisecond % members.length];
    }
    character = PjskGenerator.characterMap[character] ?? character;
    if (_selectedSticker != -1) {
      character = '$character$_selectedSticker';
    }
    // _file = await PjskGenerator.pjsk(content: content, character: character);
    _byteData = await PjskGenerator.pjsk(
      content: content,
      character: character,
      font: _font,
      pos: _pos,
      fontSize: _fontSize,
      edgeSize: _edgeSize,
      lean: _lean,
      color: _moreSettingsEnabled ? _moreSettingsColor : null,
    );

    // _time++;
    setState(() {});
  }

  Future<void> _selectCharacter1() async {
    _selected = false;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView.builder(
          itemCount: PjskGenerator.groups.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              final String group = "随机";
              final Color color = Theme.of(context).colorScheme.primary;
              final ThemeData theme = Theme.of(
                context,
              ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: color));
              return ListTile(
                // ✅ 核心属性绑定
                onTap: () {
                  setState(() {
                    _selectedGroup = group;
                    _character = group; // 直接赋值给最终显示的character
                  });
                  _createSticker();
                  Navigator.pop(context); // 选择后关闭弹窗
                },

                // ✅ 视觉优化
                title: Text(
                  group,
                  style: theme.textTheme.titleMedium!.copyWith(color: color),
                ),
                // activeColor: Theme.of(context).colorScheme.primary,
                // tileColor: Theme.of(context).colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                ).copyWith(left: 32),

                // ✅ 主题继承
                // controlAffinity: ListTileControlAffinity.leading,
                dense: true,
                visualDensity: VisualDensity.compact,
              );
            }
            index--;
            final String group = PjskGenerator.groups[index];
            final Color color = PjskGenerator.groupColor[group]!;
            final ThemeData theme = Theme.of(
              context,
            ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: color));
            // return Container();
            return Column(
              children: List.generate(
                PjskGenerator.groupMembers[group]!.length + 2,
                (index) {
                  if (index == 0) {
                    return Divider();
                  }
                  index--;
                  if (index == 0) {
                    final Color color = PjskGenerator.groupColor[group]!;
                    final ThemeData theme = Theme.of(context).copyWith(
                      colorScheme: ColorScheme.fromSeed(seedColor: color),
                    );
                    return ListTile(
                      // ✅ 核心属性绑定
                      onTap: () {
                        setState(() {
                          _selectedGroup = group;
                          _character = _selectedGroup!; // 直接赋值给最终显示的character
                        });
                        _createSticker();
                        Navigator.pop(context); // 选择后关闭弹窗
                      },

                      // ✅ 视觉优化
                      title: Text(
                        group,
                        style: theme.textTheme.titleMedium!.copyWith(
                          color: color,
                        ),
                      ),
                      // activeColor: Theme.of(context).colorScheme.primary,
                      // tileColor: Theme.of(context).colorScheme.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ).copyWith(left: 32),

                      // ✅ 主题继承
                      // controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    );
                  }
                  index--;
                  final String character =
                      PjskGenerator.groupMembers[group]![index];
                  final String name = PjskGenerator.characterMap[character]!;
                  final Color color = PjskGenerator.characterColor[name]!;
                  return ListTile(
                    // ✅ 核心属性绑定
                    onTap: () async {
                      setState(() {
                        _selectedCharacter = character;
                        // _character = character; // 直接赋值给最终显示的character
                      });
                      await _selectCharacter3();
                      if (_selected && mounted) {
                        setState(() {});
                        Navigator.pop(context); // 选择后关闭弹窗
                      }
                    },

                    // ✅ 视觉优化
                    title: Text(
                      character,
                      style: theme.textTheme.titleMedium!.copyWith(
                        color: color,
                      ),
                    ),
                    // activeColor: Theme.of(context).colorScheme.primary,
                    // tileColor: Theme.of(context).colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                    ).copyWith(left: 64),

                    // ✅ 主题继承
                    // controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _selectCharacter3() async {
    _selectedSticker = -1;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        final String name = PjskGenerator.characterMap[_selectedCharacter]!;
        final Color color = PjskGenerator.characterColor[name]!;
        final ThemeData theme = Theme.of(
          context,
        ).copyWith(colorScheme: ColorScheme.fromSeed(seedColor: color));
        return ListView(
          children: [
            ListTile(
              onTap: () {
                setState(() {
                  _character = _selectedCharacter!;
                  _selectedSticker = -1;
                });
                _createSticker();
                _selected = true;
                Navigator.pop(context); // 选择后关闭弹窗
              },
              title: Text(
                _selectedCharacter!,
                style: theme.textTheme.titleMedium!.copyWith(color: color),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
              ).copyWith(left: 32),
              dense: true,
              visualDensity: VisualDensity.compact,
            ),
            SingleChildScrollView(
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true, // 关键修复
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, // 每行 3 列
                  mainAxisSpacing: 8, // 垂直间距
                  crossAxisSpacing: 8, // 水平间距
                  childAspectRatio: 1.0, // 宽高比 1:1（适合正方形贴纸）
                ),
                itemCount: PjskGenerator.characterStickers[name]!.length,
                itemBuilder: (context, index) {
                  final String stickerPath =
                      'assets/characters/$name/${PjskGenerator.characterStickers[name]![index]}'; // 贴纸资源路径
                  // 修复RangeError：文件名格式为[name][index].png，需要正确解析索引
                  final int stickerIndex =
                      int.tryParse(
                        PjskGenerator.characterStickers[name]![index]
                            .replaceAll(name, '') // 移除角色名称部分
                            .split('.')[0], // 获取数字部分
                      )!; // 贴纸索引
                  // 判断文件是否存在
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _character = _selectedCharacter!;
                        _selectedSticker = stickerIndex; // 记录选中的贴纸索引
                      });
                      _createSticker();
                      _selected = true;
                      Navigator.pop(context);
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        stickerPath, // 加载贴纸图片
                        fit: BoxFit.cover,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _moreSettings() async {
    Color _selectedColor = _moreSettingsColor;
    await showModalBottomSheet(
      context: context,
      builder: (context) {
        return ListView(
          children: [
            ListTile(
              title: Text('更多设置'),
              onTap: () {
                setState(() {
                  _moreSettingsEnabled = !_moreSettingsEnabled;
                });
                _createSticker();
                Navigator.pop(context);
              },
              trailing: Switch(
                value: _moreSettingsEnabled,
                onChanged: (value) {
                  setState(() {
                    _moreSettingsEnabled = value;
                  });
                  _createSticker();
                  Navigator.pop(context);
                },
              ),
            ),
            ListTile(
              title: Text('设置颜色'),
              onTap: () {
                Navigator.pop(context);
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('选择颜色'),
                        content: SingleChildScrollView(
                          child: ColorPicker(
                            pickerColor: _selectedColor,
                            enableAlpha: false,
                            onColorChanged: (color) {
                              setState(() => _selectedColor = color);
                            },
                            pickerAreaHeightPercent: 0.8,
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _moreSettingsEnabled = true;
                                _moreSettingsColor = _selectedColor;
                              });
                              _createSticker();
                              Navigator.pop(context);
                            },
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                );
              },
              trailing: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  width: 24,
                  height: 24,
                  color: _moreSettingsColor,
                  // child: Text('#${_moreSettingsColor.toString()}'),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Project Sekai Sticker'),
        actions: [
          IconButton(
            icon: Icon(Ionicons.information_circle),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => const AboutPage(),
                ),
              );
              await _createSticker();
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          ListTile(title: Text("导出/导入配置"), onTap: _exportImportConfig),
          ListTile(
            title: TextField(
              controller: _contextController,
              decoration: const InputDecoration(labelText: '内容'),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              onChanged: (context) {
                _createSticker();
              },
            ),
          ),
          ListTile(
            title: InkWell(
              onTap: () {
                _selectCharacter1();
              },
              child: Text('角色: $_character'),
            ),
          ),
          ListTile(
            title: DropdownButtonFormField<int>(
              decoration: InputDecoration(labelText: '字体'),
              value: _font,
              icon: Icon(
                Ionicons.chevron_down, // 使用Ionicons图标（需导入ionicons包）
              ),
              items: [
                for (int i = 0; i < PjskGenerator.fonts.length; i++)
                  DropdownMenuItem<int>(
                    value: i,
                    child: Text(PjskGenerator.fonts[i]),
                  ),
              ],
              onChanged: (value) {
                setState(() {
                  _font = value!;
                });
                _createSticker();
              },
            ),
          ),
          ListTile(
            leading: InkWell(
              child: Text('X轴位置'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final posController = TextEditingController();
                    posController.text = _pos.dx.round().toString();
                    return AlertDialog(
                      title: Text('X轴位置'),
                      content: TextField(
                        controller: posController,
                        decoration: const InputDecoration(labelText: 'X轴位置'),
                      ),
                      actions: [
                        TextButton(
                          child: Text('取消'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            setState(() {
                              _pos = Offset(
                                double.parse(posController.text),
                                _pos.dy,
                              );
                            });
                            _createSticker();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            title: Slider(
              value: _pos.dx.clamp(-100, 300),
              min: -100,
              max: 300,
              divisions: 400,
              label: 'X轴位置: ${_pos.dx.round()}',
              onChanged: (value) {
                setState(() {
                  _pos = Offset(value, _pos.dy);
                });
                _createSticker();
              },
            ),
          ),
          ListTile(
            leading: InkWell(
              child: Text('Y轴位置'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final posController = TextEditingController();
                    posController.text = _pos.dy.round().toString();
                    return AlertDialog(
                      title: Text('Y轴位置'),
                      content: TextField(
                        controller: posController,
                        decoration: const InputDecoration(labelText: 'Y轴位置'),
                      ),
                      actions: [
                        TextButton(
                          child: Text('取消'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            setState(() {
                              _pos = Offset(
                                _pos.dx,
                                double.parse(posController.text),
                              );
                            });
                            _createSticker();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            title: Slider(
              value: _pos.dy.clamp(-100, 300),
              min: -100,
              max: 300,
              divisions: 400,
              label: 'Y轴位置: ${_pos.dy.round()}',
              onChanged: (value) {
                setState(() {
                  _pos = Offset(_pos.dx, value);
                });
                _createSticker();
              },
            ),
          ),
          ListTile(
            leading: InkWell(
              child: Text('字体大小'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final fontSizeController = TextEditingController();
                    fontSizeController.text = _fontSize.round().toString();
                    return AlertDialog(
                      title: Text('字体大小'),
                      content: TextField(
                        controller: fontSizeController,
                        decoration: const InputDecoration(labelText: '字体大小'),
                      ),
                      actions: [
                        TextButton(
                          child: Text('取消'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            setState(() {
                              _fontSize = double.parse(fontSizeController.text);
                            });
                            _createSticker();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            title: Slider(
              value: _fontSize.clamp(00, 100),
              min: 0,
              max: 100,
              divisions: 100,
              label: '字体大小: ${_fontSize.round()}',
              onChanged: (value) {
                setState(() {
                  _fontSize = value;
                });
                _createSticker();
              },
            ),
          ),
          ListTile(
            leading: InkWell(
              child: Text('旋转角度'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    final leanController = TextEditingController();
                    leanController.text = _lean.round().toString();
                    return AlertDialog(
                      title: Text('旋转角度'),
                      content: TextField(
                        controller: leanController,
                        decoration: const InputDecoration(labelText: '字体大小'),
                      ),
                      actions: [
                        TextButton(
                          child: Text('取消'),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                        TextButton(
                          child: Text('确定'),
                          onPressed: () {
                            setState(() {
                              _lean = double.parse(leanController.text);
                            });
                            _createSticker();
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            title: Slider(
              value: _lean.clamp(-180, 180),
              min: -180,
              max: 180,
              divisions: 360,
              label: '旋转角度: ${_lean.round()}',
              onChanged: (value) {
                setState(() {
                  _lean = value;
                });
                _createSticker();
              },
            ),
          ),
          ListTile(title: Text('更多设置'), onTap: _moreSettings),
          if (_byteData != null)
            ListTile(
              title: Image.memory(
                key: ValueKey(_byteData.hashCode),
                _byteData!,
                width: 300,
                height: 300,
              ),
              onTap: () async {
                try {
                  // await Pasteboard.writeFiles([_byteData!]);
                  // await Future.delayed(Duration(seconds: 1));
                  if (kIsWeb) {
                    downloadImageWeb(_byteData!);
                  } else if (Platform.isAndroid) {
                    final File file = File(
                      '/storage/emulated/0/Pictures/pjsk_sticker/pjsk_${DateTime.now().millisecondsSinceEpoch}.png',
                    );
                    await file.create(recursive: true);
                    // await _file!.copy(file.path);
                    await file.writeAsBytes(_byteData!);
                    // await Pasteboard.writeFiles([file.path]);
                    await SharePlus.instance.share(
                      // ShareParams(files: [XFile(file.path)]),
                      ShareParams(
                        files: [XFile.fromData(_byteData!, path: file.path)],
                      ),
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已将图片保存到相册')));
                    }
                  } else {
                    final File file = File(
                      'pjsk_sticker/pjsk_${DateTime.now().millisecondsSinceEpoch}.png',
                    );
                    await file.create(recursive: true);
                    await file.writeAsBytes(_byteData!);
                    if (Platform.isWindows) {
                      print(file.path.replaceAll('/', '\\'));
                      await Process.run('explorer.exe', [
                        '/select,${file.path.replaceAll('/', '\\')}',
                      ]);
                      Pasteboard.writeFiles([file.path.replaceAll('/', '\\')]);
                    } else {
                      Pasteboard.writeFiles([file.path]);
                    }
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已复制图片到粘贴板并保存当前文件夹下')),
                      );
                    }
                  }
                } catch (e) {
                  if (kDebugMode) {
                    print(e);
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}
