# PJSK-Sticker 项目代码分析报告

> 本文档由 25 个并行子代理深度分析项目代码后自动生成
> 生成时间：2025-01-XX
> 分析范围：完整代码库（包括核心逻辑、UI、平台代码、配置、测试）

---

## 📋 目录

1. [项目概述](#项目概述)
2. [整体架构](#整体架构)
3. [核心模块](#核心模块)
4. [平台支持](#平台支持)
5. [开发配置](#开发配置)
6. [测试与质量](#测试与质量)
7. [国际化](#国际化)
8. [CI/CD](#cicd)
9. [技术债务与改进建议](#技术债务与改进建议)

---

## 项目概述

**项目名称**: PJSK Sticker (Project Sekai Sticker Maker)
**技术栈**: Flutter 3.7.2+ / Dart
**项目类型**: 跨平台表情包生成器
**支持平台**: Android、iOS、Windows、macOS、Linux
**核心功能**: 在《世界计划 彩色舞台！feat. 初音未来》角色资源上叠加自定义文字，生成个性化表情包

### 关键特性

- ✅ **多图层文本编辑**：支持无限图层，每层独立配置
- ✅ **高级文字效果**：倾斜、弯曲、描边、透明度、自定义颜色
- ✅ **字体管理系统**：动态下载和加载 TTF/OTF 字体
- ✅ **配置导入导出**：支持 URI 和 ZIP 两种格式
- ✅ **自定义底图**：支持用户上传自定义背景
- ✅ **Material You**：动态主题色支持
- ✅ **自动更新检查**：从 GitHub Releases 检查更新
- ✅ **完整国际化**：支持中文（简繁）、日语、英语

### 资源规模

- **26 个角色**：包括 PJSK 主要角色和 VOCALOID
- **700+ 张贴纸**：每个角色 25-41 张不等
- **100+ 翻译键**：覆盖所有功能模块

---

## 整体架构

### 架构风格

**单体分层架构 (Layered Monolithic Architecture)**

```
┌─────────────────────────────────────┐
│   Presentation Layer (UI)           │  ← pages/*, widgets
├─────────────────────────────────────┤
│   Business Logic Layer              │  ← sticker.dart, *_logic.dart
├─────────────────────────────────────┤
│   Service Layer                     │  ← font_manager, update_checker
├─────────────────────────────────────┤
│   Data Layer                        │  ← SharedPreferences, File I/O
└─────────────────────────────────────┘
```

### 模块划分

```
lib/
├── main.dart                      # 应用入口
├── pages/
│   ├── app.dart                   # 启动流程控制
│   ├── sticker.dart               # 贴纸编辑器（主功能）
│   ├── sticker/                   # 贴纸页面子模块
│   │   ├── sticker_page_logic.dart
│   │   ├── sticker_page_config.dart
│   │   ├── sticker_page_config_zip.dart
│   │   ├── sticker_page_layers.dart
│   │   ├── sticker_page_picker.dart
│   │   └── sticker_page_sections.dart
│   ├── settings.dart              # 设置页面
│   └── font_settings.dart         # 字体管理
├── sticker.dart                   # 贴纸生成引擎
├── sticker_config_archive.dart    # 配置归档系统
├── image_text_overlay.dart        # 图像渲染引擎
├── font_manager.dart              # 字体管理器
├── build_info.dart                # 构建信息
├── update/                        # 更新检查模块
│   ├── update_checker.dart
│   ├── update_info.dart
│   └── update_prompt.dart
└── l10n/                          # 国际化资源
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    ├── app_localizations_ja.dart
    └── app_localizations_zh.dart
```

### 设计模式

| 模式 | 应用场景 | 文件位置 |
|------|---------|---------|
| **单例模式** | FontManager | `font_manager.dart` |
| **工厂模式** | TextLayer.fromJson | `sticker.dart` |
| **外观模式** | PjskGenerator.pjsk | `sticker.dart` |
| **策略模式** | 文字渲染（直线/曲率） | `image_text_overlay.dart` |
| **观察者模式** | setState 机制 | 所有 StatefulWidget |
| **缓存模式** | 图片/字体缓存 | `sticker.dart` |
| **依赖注入** | UpdateChecker | `update_checker.dart` |

---

## 核心模块

### 1. 贴纸生成引擎 (PjskGenerator)

**文件**: `lib/sticker.dart`

#### 核心功能
- 管理 26 个角色和 700+ 张贴纸资源
- 双层缓存系统（图片 + 字体）
- 编排图像合成流程

#### 数据模型：TextLayer
```dart
class TextLayer {
  String id;              // 唯一标识符
  String content;         // 文本内容
  Offset pos;             // 位置坐标
  double lean;            // 倾斜角度
  double fontSize;        // 字体大小
  int edgeSize;           // 描边宽度
  int font;               // 字体索引
  bool useCustomColor;    // 自定义颜色开关
  Color customColor;      // 自定义颜色
  double opacity;         // 不透明度
  bool visible;           // 可见性
  bool locked;            // 锁定状态
  double bendCurvature;   // 弯曲曲率
  double bendSpacing;     // 弯曲间距
}
```

#### 缓存策略
- **图片缓存**：FIFO 策略，最多 30 张
- **字体缓存**：无限制（潜在风险）

#### 生成流程
```
用户输入 → 加载底图 → 预加载字体 → 构建渲染层 → 图像合成 → PNG 输出
```

---

### 2. 图像渲染引擎 (ImageTextOverlay)

**文件**: `lib/image_text_overlay.dart`

#### 核心算法

##### 描边算法
- 使用 360 个方向的 Shadow 叠加实现精确描边
- 无模糊效果（`blurRadius: 0`）

##### 弯曲文字算法
- **圆弧布局**：将文字沿圆弧排布
- **正曲率**：圆心在下方，文字向上弯曲
- **负曲率**：圆心在上方，文字向下弯曲
- **逐字符计算**：位置和旋转角度

**曲率计算公式**：
```dart
signedRadius = 1.0 / bendCurvature
theta = charArcCenter / absRadius
anchor = Offset(
  circleCenter.dx + absRadius * sin(theta),
  circleCenter.dy ± absRadius * cos(theta)
)
```

#### 渲染流程
1. 解码背景图像
2. 预加载所有字体
3. 为每个图层创建 TextPainter
4. Canvas 合成（背景 + 文本图层）
5. 导出 PNG

---

### 3. 字体管理系统 (FontManager)

**文件**: `lib/font_manager.dart`

#### 核心功能
- 字体下载与验证（仅支持 TTF/OTF）
- 字体文件本地存储
- 字体注册到 Flutter 引擎
- 字体列表持久化

#### 安全特性
- **文件头验证**：
  - TTF: `0x00010000` 或 `0x74727565`
  - OTF: `0x4F54544F`
- **不支持 WOFF/WOFF2**：防止格式错误

#### 字体注册流程
```
下载 → 验证格式 → 保存到本地 → 注册到 Flutter → 持久化配置
```

---

### 4. 配置归档系统 (StickerConfigArchive)

**文件**: `lib/sticker_config_archive.dart`

#### 支持的格式

##### URI 模式（轻量级分享）
- 参数编码：`character`, `character_index`, `layers_json`
- 限制：不支持自定义底图，URI 长度受限

##### ZIP 模式（完整归档）
```
<packName>.pjsksticker.zip
├── metadata.json              # 贴纸包元数据
└── stickers/
    └── <stickerId>/
        ├── sticker.json       # 贴纸配置
        └── background.png     # 自定义底图（可选）
```

#### 安全验证
- 路径遍历检查（禁止 `../`）
- 绝对路径检查（禁止 `/` 开头和 `:`）
- JSON Schema 验证

---

### 5. 更新检查系统

**文件**: `lib/update/update_checker.dart`

#### 核心功能
- 从 GitHub API 获取最新版本
- 语义化版本比较（使用 `pub_semver`）
- 用户忽略版本记录
- 预发布版本智能过滤

#### 版本策略
- 当前版本为预发布 → 允许检查预发布更新
- 当前版本为稳定版 → 仅检查稳定版更新

---

## 平台支持

### Android

**最低版本**: API 21 (Android 5.0)
**权限配置**:
- `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` (Android 12-)
- `READ_MEDIA_IMAGES` (Android 13+)
- `requestLegacyExternalStorage="true"`

**集成插件** (10 个):
- dynamic_color, file_picker, flutter_plugin_android_lifecycle
- image_picker, pasteboard, path_provider
- permission_handler, share_plus, shared_preferences, url_launcher

**构建配置**:
- Gradle 8.12.1
- Kotlin 2.2.0
- Java 17

---

### iOS

**最低版本**: iOS 12.0
**⚠️ 权限配置缺失**:
- 缺少 `NSPhotoLibraryUsageDescription`
- 缺少 `NSCameraUsageDescription`

**集成插件** (7 个):
- file_picker, image_picker_ios, pasteboard
- permission_handler_apple, share_plus
- shared_preferences_foundation, url_launcher_ios

**构建配置**:
- Swift 5.0
- Xcode 15.1.0
- 支持 iPhone 和 iPad

---

### Windows

**目标平台**: windows-x64
**DPI 感知**: PerMonitorV2
**窗口特性**:
- 默认尺寸：1280x720
- 自动 DPI 缩放
- 系统主题跟随

**集成插件** (6 个):
- dynamic_color, file_selector_windows, pasteboard
- permission_handler_windows, share_plus, url_launcher_windows

**构建配置**:
- C++17
- CMake 3.14+
- 禁用异常（性能优化）

---

### macOS

**最低版本**: macOS 10.14 (Mojave)
**沙盒设置**: 已启用
**权限配置**:
- Debug/Profile: JIT + 网络服务器
- Release: 仅沙盒

**集成插件** (4 个):
- dynamic_color, file_selector_linux, pasteboard, url_launcher_linux

**构建配置**:
- Swift 5.0
- 自动代码签名

---

### Linux

**应用程序 ID**: `org.parallel_sekai.pjsk_sticker`
**窗口管理器适配**:
- GNOME Shell: GTK Header Bar
- X11 非 GNOME: 传统标题栏

**集成插件** (4 个):
- dynamic_color, file_selector_linux, pasteboard, url_launcher_linux

**构建配置**:
- GTK+ 3.0
- CMake 3.13+
- C++14

---

## 开发配置

### Git 忽略规则

- **编译产物**: `*.class`, `*.pyc`, `*.log`
- **Flutter**: `.dart_tool/`, `.pub-cache/`, `/build/`
- **Android**: `/android/app/debug`, `/android/app/release`
- **敏感文件**: `key.jks`, `key.properties`
- **项目特定**: `.narrafork/`, `.worktrees/`

### VSCode 配置

```json
{
  "cmake.ignoreCMakeListsMissing": true,
  "cSpell.words": ["Pjsk"]
}
```

### 代码规范

- **Lint 规则**: `package:flutter_lints/flutter.yaml`
- **Flutter SDK**: `^3.7.2`
- **版本号**: `1.0.0+1`

---

## 测试与质量

### 测试文件

1. **widget_test.dart**: 基础 Widget 冒烟测试
2. **image_text_overlay_test.dart**: 图像文字叠加核心功能测试（20+ 用例）
3. **sticker_config_archive_test.dart**: 贴纸配置导入导出测试

### 测试覆盖范围

#### 图像文字叠加测试
- ✅ 基础功能测试（PNG 生成、边缘偏移）
- ✅ 弯曲文字渲染测试（6 个场景）
- ✅ JSON 兼容性测试（5 个场景）
- ✅ 曲率布局数学测试（圆心计算、字符布局）

#### 配置归档测试
- ✅ 导出导入测试（内置底图 + 自定义底图）
- ✅ 安全性测试（路径遍历攻击防护）
- ✅ 颜色转换测试

### 质量评估

**优势**:
- ✅ 核心算法覆盖全面
- ✅ 向后兼容性保障
- ✅ 安全性考虑
- ✅ 边界条件测试

**不足**:
- ⚠️ Widget 测试薄弱（仅有一个冒烟测试）
- ⚠️ 缺少集成测试
- ⚠️ UI 交互未覆盖
- ⚠️ 异步操作测试不足

---

## 国际化

### 支持的语言

1. **英语 (en)**
2. **日语 (ja)**
3. **简体中文 (zh)**
4. **繁体中文 (zh_Hant)**

### 实现方式

- **技术栈**: `flutter_localizations` + `intl`
- **代码生成**: Flutter 的 `gen-l10n` 工具
- **配置文件**: `l10n.yaml`

### 翻译文本分类

- **通用操作** (15 个): about, close, cancel, confirm, delete, save, share...
- **角色与贴纸选择** (5 个)
- **图层管理** (14 个)
- **文字样式** (15 个)
- **导出/导入** (13 个)
- **字体管理** (14 个)
- **更新检查** (11 个)
- **关于页面** (9 个)
- **自定义背景** (5 个)
- **撤销/重做** (4 个)

### 使用方式

```dart
// 简单字符串
Text(S.of(context).appTitle)

// 带参数的字符串
Text(S.of(context).layerDefault(1))
Text(S.of(context).confirmDeleteLayer('图层 1'))
```

---

## CI/CD

### Push CI 流程

**触发条件**: 推送到 `main` 或 `dev` 分支，或针对这些分支的 PR

**流程架构**:
```
质量检查 (quality) → 多平台构建 (build)
```

**质量检查**:
- `flutter analyze` - 静态代码分析
- `flutter test` - 单元测试

**构建平台**:
- Android: 多架构 APK (arm64-v8a, armeabi-v7a, x86_64)
- Linux: tar.gz + AppImage
- Windows: zip 压缩包

---

### Release 流程

**触发条件**: 推送以 `v` 开头的 tag（如 `v1.0.0`）

**流程架构**:
```
多平台构建 (build) → 创建 GitHub Release (release)
```

**发布产物**:
- `*-arm64-v8a.apk` (Android ARM64)
- `*-armeabi-v7a.apk` (Android ARMv7)
- `*-x86_64.apk` (Android x86_64)
- `windows-release.zip` (Windows)
- `linux-release.tar.gz` (Linux 原始包)
- `PJSK_Sticker-x86_64.AppImage` (Linux AppImage)

---

### 其他自动化

1. **Dependabot**: 每日检查依赖更新
2. **Auto Assign**: 自动分配 Issue/PR 给 `xiaocaoooo`
3. **Pre-commit Hooks**:
   - `dart-format` - 自动格式化 Dart 代码
   - `trailing-whitespace` - 移除行尾空白
   - `end-of-file-fixer` - 确保文件以换行符结尾
   - `check-yaml` - 验证 YAML 文件语法

---

## 技术债务与改进建议

### 当前问题

1. **字体缓存无限制**
   - 现状: `_fontCache` 无 LRU 策略，可能无限增长
   - 建议: 添加 LRU 淘汰策略或容量限制

2. **状态管理**
   - 现状: 使用 setState，大型状态难以管理
   - 建议: 引入 Riverpod 或 Bloc 进行状态管理

3. **iOS 权限配置缺失**
   - 现状: 缺少 `NSPhotoLibraryUsageDescription` 和 `NSCameraUsageDescription`
   - 建议: 在 Info.plist 中添加必要的权限描述

4. **错误处理不一致**
   - 现状: 图片加载失败静默回退，配置导入失败抛出异常
   - 建议: 统一错误处理策略

5. **测试覆盖不足**
   - 现状: 仅有少量单元测试，缺少 Widget 测试和集成测试
   - 建议: 增加测试覆盖率，特别是 UI 交互测试

---

### 优化建议

1. **异步优化**
   - 字体预加载可并行执行
   - 使用 `Future.wait()` 提升性能

2. **资源验证**
   - 在构建时验证所有资源路径
   - 避免运行时回退

3. **配置版本管理**
   - 当前版本号硬编码为 "1.0.0"
   - 建议: 添加版本迁移机制

4. **性能优化**
   - 增加脏检查机制，仅在必要时重新生成贴纸
   - 优化图片缓存策略

5. **代码组织**
   - `sticker.dart` 文件过长（1262 行）
   - 建议: 进一步拆分为独立模块

---

## 总结

PJSK-Sticker 是一个架构清晰、功能完善的 Flutter 应用。项目采用传统的分层架构，通过合理的模块划分和设计模式应用，实现了高性能的图像渲染和良好的用户体验。

### 核心亮点

- ✅ 底层 Canvas 渲染实现复杂文字效果
- ✅ 完善的缓存和内存管理策略
- ✅ 安全的文件处理和配置归档系统
- ✅ 良好的跨平台兼容性
- ✅ 完整的国际化支持
- ✅ 自动化 CI/CD 流程

### 改进方向

- 引入现代状态管理方案
- 增强测试覆盖率
- 优化性能和错误处理
- 完善平台特定配置

整体而言，这是一个设计合理、实现优秀的开源项目，适合作为 Flutter 图像处理应用的参考案例。

---

## 附录：资源统计

- **代码文件**: 50+ 个 Dart 文件
- **平台代码**: Android (Java/Kotlin), iOS (Swift/Objective-C), Windows (C++), macOS (Swift), Linux (C++)
- **资源文件**: 700+ 张贴纸图片
- **角色数量**: 26 个
- **翻译键**: 100+ 个
- **测试用例**: 20+ 个
- **依赖包**: 20+ 个

---

**文档生成**: 由 25 个并行子代理深度分析项目代码后自动生成
**分析工具**: Claude Code (Kiro)
**项目地址**: https://github.com/Parallel-SEKAI/PJSK-Sticker
