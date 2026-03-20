import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:pjsk_sticker/build_info.dart';
import 'package:pjsk_sticker/update/update_info.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef SharedPreferencesProvider = Future<SharedPreferences> Function();
typedef CurrentVersionProvider = String Function();

class UpdateChecker {
  UpdateChecker({
    http.Client? client,
    SharedPreferencesProvider? prefsProvider,
    CurrentVersionProvider? currentVersionProvider,
  }) : _client = client ?? http.Client(),
       _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
       _currentVersionProvider =
           currentVersionProvider ?? (() => BuildInfo.appVersion);

  static final Uri _releasesUri = Uri.parse(
    'https://api.github.com/repos/Parallel-SEKAI/PJSK-Sticker/releases?per_page=20',
  );

  static const String _ignoredVersionKey = 'ignored_update_version';
  static const String _userAgent = 'PJSK-Sticker-App';

  final http.Client _client;
  final SharedPreferencesProvider _prefsProvider;
  final CurrentVersionProvider _currentVersionProvider;

  Future<UpdateInfo?> checkForUpdate({required bool manual}) async {
    final Version currentVersion = parseComparableVersion(
      _currentVersionProvider(),
    );
    final bool allowPrerelease = currentVersion.isPreRelease;
    final String? ignoredVersion = await _readIgnoredVersion();

    final http.Response response = await _client.get(
      _releasesUri,
      headers: <String, String>{
        'Accept': 'application/vnd.github+json',
        'User-Agent': _userAgent,
        if (manual) 'Cache-Control': 'no-cache',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch releases: HTTP ${response.statusCode}');
    }

    final dynamic payload = jsonDecode(response.body);
    if (payload is! List) {
      throw const FormatException('Invalid releases payload');
    }

    final List<UpdateInfo> candidates = <UpdateInfo>[];
    for (final dynamic item in payload) {
      if (item is! Map) {
        continue;
      }
      if (item['draft'] == true) {
        continue;
      }

      final String? tagName = item['tag_name'] as String?;
      if (tagName == null || tagName.isEmpty) {
        continue;
      }

      final Version releaseVersion;
      try {
        releaseVersion = parseComparableVersion(tagName);
      } on FormatException {
        continue;
      }

      final bool releaseIsPrerelease =
          item['prerelease'] == true || releaseVersion.isPreRelease;
      if (!allowPrerelease && releaseIsPrerelease) {
        continue;
      }
      if (releaseVersion <= currentVersion) {
        continue;
      }

      final String? htmlUrlValue = item['html_url'] as String?;
      final Uri? htmlUrl =
          htmlUrlValue == null ? null : Uri.tryParse(htmlUrlValue);
      if (htmlUrl == null) {
        continue;
      }

      final String releaseNotes = ((item['body'] as String?) ?? '').trim();
      final String? publishedAtRaw = item['published_at'] as String?;
      final DateTime? publishedAt =
          publishedAtRaw == null ? null : DateTime.tryParse(publishedAtRaw);

      candidates.add(
        UpdateInfo(
          tagName: tagName,
          semanticVersion: releaseVersion,
          isPrerelease: releaseIsPrerelease,
          publishedAt: publishedAt?.toUtc(),
          releaseNotes: releaseNotes,
          htmlUrl: htmlUrl,
        ),
      );
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort(
      (UpdateInfo a, UpdateInfo b) =>
          b.semanticVersion.compareTo(a.semanticVersion),
    );
    final UpdateInfo latest = candidates.first;
    if (ignoredVersion != null && ignoredVersion == latest.version) {
      return null;
    }

    return latest;
  }

  Future<void> ignoreVersion(String version) async {
    final SharedPreferences prefs = await _prefsProvider();
    final String normalized = parseComparableVersion(version).toString();
    await prefs.setString(_ignoredVersionKey, normalized);
  }

  Future<String?> _readIgnoredVersion() async {
    final SharedPreferences prefs = await _prefsProvider();
    final String? ignored = prefs.getString(_ignoredVersionKey);
    if (ignored == null || ignored.trim().isEmpty) {
      return null;
    }

    try {
      return parseComparableVersion(ignored).toString();
    } on FormatException {
      await prefs.remove(_ignoredVersionKey);
      return null;
    }
  }

  @visibleForTesting
  static Version parseComparableVersion(String rawVersion) {
    final String trimmed = rawVersion.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Version is empty.');
    }

    final String withoutPrefix =
        trimmed.startsWith('v') || trimmed.startsWith('V')
            ? trimmed.substring(1)
            : trimmed;
    final String withoutBuild = withoutPrefix.split('+').first;
    if (withoutBuild.isEmpty) {
      throw FormatException('Invalid version: $rawVersion');
    }

    return Version.parse(withoutBuild);
  }
}
