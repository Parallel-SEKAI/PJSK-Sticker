# GEMINI.md - PJSK Sticker Project Documentation

## 1. Purpose
**PJSK Sticker** (Project Sekai Sticker Maker) is a cross-platform application built with Flutter, designed for fans of the game *Project Sekai: Colorful Stage! feat. Hatsune Miku*. It enables users to create personalized stickers by overlaying custom, styled text on character-specific game assets. The app features a high-fidelity rendering engine that mimics the game's iconic sticker style, including multi-shadow text outlines and specific Japanese fonts.

## 2. Tech Stack
- **Primary Language**: Dart (Flutter SDK)
- **Framework**: Flutter 3.7.2 or higher
- **Design System**: Material 3 with Dynamic Color support
- **Target Platforms**:
  - **Mobile**: Android (optimized for Android 16/HyperOS), iOS
  - **Desktop**: Windows, macOS, Linux (support for file saving and clipboard)
  - **Web**: Flutter Web (Canvas-based rendering with custom font loading)

## 3. File Directory & Responsibilities
```text
/home/xiaocaoooo/code/PJSK-Sticker/
├── assets/                  # Static resources
│   ├── characters/          # Subfolders per character containing PNG assets
│   ├── icon.png             # App icon
│   └── wechat.png           # WeChat-related asset
├── Fonts/                   # Custom TrueType fonts
│   ├── YurukaStd.ttf        # Primary game-style font
│   └── MaokenAssortedSans.ttf # Alternative decorative font
├── lib/                     # Application source code
│   ├── pages/               # UI Layer
│   │   ├── app.dart         # Main application wrapper and first-launch/license logic
│   │   ├── sticker.dart     # Primary workspace: layer management and sticker preview
│   │   └── about.dart       # App info and legal notices
│   ├── image_text_overlay.dart # Core rendering engine (Canvas-based)
│   ├── main.dart            # App entry point, permission handling, and theme config
│   ├── sticker.dart         # Metadata provider and generation orchestrator
│   ├── web_utils.dart       # Web-specific file download utilities
│   └── web_utils_stub.dart  # Native stub for web utilities
├── test/                    # Automated tests
│   ├── image_text_overlay_test.dart # Unit tests for rendering logic
│   └── widget_test.dart      # UI component tests
└── pubspec.yaml             # Project configuration and dependencies
```

## 4. Dependencies & Modules
| Dependency            | Purpose                                                             |
| --------------------- | ------------------------------------------------------------------- |
| `dynamic_color`       | Implements Material 3 dynamic theming based on system wallpaper.    |
| `flutter_colorpicker` | Provides UI for selecting custom text colors.                       |
| `path_provider`       | Handles platform-specific file system paths.                        |
| `pasteboard`          | Enables copying generated images to the system clipboard (Desktop). |
| `share_plus`          | Facilitates sharing generated stickers to other applications.       |
| `shared_preferences`  | Persists user settings (character selection, layers, fonts).        |
| `permission_handler`  | Manages storage and photo permissions on Android/iOS.               |
| `http`                | Support for external API interactions (configuration sharing).      |

## 5. Naming & Coding Conventions
- **Language Style**: Follows [Effective Dart](https://dart.dev/guides/language/effective-dart) (camelCase for variables, PascalCase for classes).
- **Architecture**: **Layer-first**. 
  - **Data/Logic**: Isolated in `PjskGenerator` and `ImageTextOverlay`.
  - **UI**: Managed via `StatefulWidget` using local `setState` for high-frequency updates (like position sliders).
- **State Persistence**: User progress is automatically serialized to JSON and stored via `SharedPreferences`.

## 6. Core Classes & Functions Index
### `PjskGenerator` (lib/sticker.dart)
- `TextLayer`: Data model for a single text layer. Now uses compressed JSON keys (`c`, `x`, `y`, etc.) for URL length optimization and includes backward compatibility for old formats.
- `pjsk()`: Orchestrates the sticker generation process. Utilizes static caches (`_imageCache`, `_fontCache`) with a FIFO (First-In-First-Out) eviction policy for images (30 items limit) to ensure smooth performance.
- `characterMap` / `characterStickers`: Metadata mapping.

### `ImageTextOverlay` (lib/image_text_overlay.dart)
- `generateStickerFromBytes()`: The engine for image compositing. Now includes a `_fontLoadFutures` map to manage concurrent font loading requests, ensuring each custom font is registered with the Flutter engine exactly once and avoiding race conditions during multi-layer rendering.
- `_createTextPainter()`: Handles complex text styling with multi-shadow outline effects.
- `_compositeImages()`: Performs canvas transformations for multi-layer rendering.

### `StickerPage` (lib/pages/sticker.dart)
- `_layers`: List of `TextLayer` managed in state.
- `_currentLayerId`: Currently selected layer ID (ensures stable selection during list mutations). Now protected by a robust getter that ensures at least one layer exists.
- `_createSticker()`: Aggregates UI state and calls the generator.
- `_debouncedCreateSticker()`: A debounced wrapper (300ms) for `_createSticker()` to ensure smooth UI performance during slider adjustments.
- `_saveAsUri()` / `_reloadFromUri()`: Serialization logic for exporting/importing configurations as URLs (using JSON for layers). Now includes enhanced safety with `tryParse` for numeric/color parameters and robust migration for old configuration formats. (Note: UI entry for sharing is temporarily hidden).

## 7. Implementation Logic
1. **Asset Management**: Character assets are organized by folder. The app uses `rootBundle` to load PNGs and TTF files on demand.
2. **Rendering Pipeline**:
   - Background image is decoded into a `ui.Image`.
   - Fonts are registered dynamically via `FontLoader`.
   - For each `TextLayer`, a `TextPainter` is created with a `Shadow` list (360-degree circular offsets) to create the outline.
   - Layers are drawn onto a `Canvas` with independent coordinate transforms.
3. **Configuration Sharing**: The app generates a URL containing a Base64-encoded or JSON-encoded representation of the layers, allowing users to share their "recipes".

## 8. Agent Development Instructions (AI Context)
- **Error Handling**: 
  - Wrap all asset loading and file I/O in `try-catch` blocks.
  - Use `ScaffoldMessenger` to provide user feedback for failures.
- **State Management**: 
  - Keep using `setState` for local UI state in `StickerPage`.
  - For new global features, use `SharedPreferences` for persistence.
- **UI Consistency**: 
  - Always use `Theme.of(context).colorScheme` to ensure Material 3 compatibility.
  - New settings should be added within `ExpansionTile` widgets to maintain a clean layout.
- **Platform Specifics**: 
  - Use `kIsWeb` and `Platform.is...` checks for file-saving logic.
  - Ensure `web_utils.dart` and `web_utils_stub.dart` are updated if adding new web-specific features.
- **Testing**:
  - Add unit tests for any new rendering logic in `test/image_text_overlay_test.dart`.
  - Run `flutter analyze` and `flutter test` before submitting changes.
