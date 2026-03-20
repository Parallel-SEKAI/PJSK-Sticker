import 'package:pub_semver/pub_semver.dart';

class UpdateInfo {
  UpdateInfo({
    required this.tagName,
    required this.semanticVersion,
    required this.isPrerelease,
    required this.publishedAt,
    required this.releaseNotes,
    required this.htmlUrl,
  });

  final String tagName;
  final Version semanticVersion;
  final bool isPrerelease;
  final DateTime? publishedAt;
  final String releaseNotes;
  final Uri htmlUrl;

  String get version => semanticVersion.toString();
}
