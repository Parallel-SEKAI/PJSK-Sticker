import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:intl/intl.dart';
import 'package:pjsk_sticker/l10n/app_localizations.dart';
import 'package:pjsk_sticker/update/update_checker.dart';
import 'package:pjsk_sticker/update/update_info.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showUpdateDialog({
  required BuildContext context,
  required UpdateChecker checker,
  required UpdateInfo updateInfo,
}) async {
  final S s = S.of(context);
  final String localeName = Localizations.localeOf(context).toString();
  final String dateText =
      updateInfo.publishedAt == null
          ? '-'
          : DateFormat.yMd(
            localeName,
          ).add_Hms().format(updateInfo.publishedAt!.toLocal());
  final String notes =
      updateInfo.releaseNotes.isEmpty
          ? s.releaseNotesEmpty
          : updateInfo.releaseNotes;

  Future<void> openMarkdownLink(String? href) async {
    if (href == null || href.isEmpty) {
      return;
    }
    final Uri? uri = Uri.tryParse(href);
    if (uri == null) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.linkOpenFailed(href))));
      return;
    }

    final bool launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!context.mounted || launched) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(s.linkOpenFailed(uri.toString()))));
  }

  await showAdaptiveDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(s.newVersionFound(updateInfo.version)),
        content: SizedBox(
          width: 560,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(s.releaseDate(dateText)),
                const SizedBox(height: 12),
                MarkdownBody(
                  data: notes,
                  selectable: true,
                  onTapLink: (text, href, title) async {
                    await openMarkdownLink(href);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await checker.ignoreVersion(updateInfo.version);
              if (!dialogContext.mounted) {
                return;
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(s.ignoreThisVersion),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(s.updateLater),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              final bool launched = await launchUrl(
                updateInfo.htmlUrl,
                mode: LaunchMode.externalApplication,
              );
              if (!context.mounted || launched) {
                return;
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    s.linkOpenFailed(updateInfo.htmlUrl.toString()),
                  ),
                ),
              );
            },
            child: Text(s.updateNow),
          ),
        ],
      );
    },
  );
}
