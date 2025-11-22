import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:pjsk_sticker/pages/app.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  // 初始化Flutter绑定
  WidgetsFlutterBinding.ensureInitialized();
  
  // 请求存储权限
  requestStoragePermission();
  
  runApp(const MyApp());
}

/// 请求存储权限的异步函数
Future<void> requestStoragePermission() async {
  // 对于Android 13及以上版本，使用photos和videos权限
  if (await Permission.photos.isDenied) {
    await Permission.photos.request();
  }
  
  // 对于Android 12及以下版本，使用storage权限
  if (await Permission.storage.isDenied) {
    await Permission.storage.request();
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;

        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(seedColor: Color(0xFFDDAACC));
          darkColorScheme = ColorScheme.fromSeed(
            seedColor: Color(0xFFDDAACC),
            brightness: Brightness.dark,
          );
        }

        return MaterialApp(
          title: 'PJSK Sticker',
          theme: ThemeData(
            colorScheme: lightColorScheme,
          ),
          darkTheme: ThemeData(
            colorScheme: darkColorScheme,
          ),
          home: AppPage(),
        );
      },
    );
  }
}
