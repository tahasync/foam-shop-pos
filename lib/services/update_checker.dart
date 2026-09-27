import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppUpdateConfig {
  static const repoOwner = 'tahasync';
  static const repoName = 'foam-shop-pos';
  static const apiUrl =
      'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const latestReleaseUrl =
      'https://github.com/$repoOwner/$repoName/releases/latest';
  static const downloadUrl =
      'https://github.com/$repoOwner/$repoName/releases/download';
}

class UpdateInfo {
  final String tagName;
  final String htmlUrl;
  final String body;
  final DateTime publishedAt;
  const UpdateInfo({
    required this.tagName,
    required this.htmlUrl,
    required this.body,
    required this.publishedAt,
  });
}

Future<UpdateInfo?> checkForUpdate() async {
  try {
    final response = await http.get(
      Uri.parse(AppUpdateConfig.apiUrl),
      headers: {'Accept': 'application/vnd.github.v3+json'},
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tag = data['tag_name'] as String? ?? '';
    final url = data['html_url'] as String? ?? '';
    final body = data['body'] as String? ?? '';
    final published = DateTime.tryParse(data['published_at'] as String? ?? '');
    if (tag.isEmpty) return null;
    return UpdateInfo(
        tagName: tag,
        htmlUrl: url,
        body: body,
        publishedAt: published ?? DateTime.now());
  } catch (_) {
    return null;
  }
}

bool isNewerVersion(String installed, String remote) {
  final iParts = installed.replaceAll(RegExp(r'^v'), '').split('.');
  final rParts = remote.replaceAll(RegExp(r'^v'), '').split('.');
  final maxLen = iParts.length > rParts.length ? iParts.length : rParts.length;
  for (int i = 0; i < maxLen; i++) {
    final iv = int.tryParse(iParts.length > i ? iParts[i] : '0') ?? 0;
    final rv = int.tryParse(rParts.length > i ? rParts[i] : '0') ?? 0;
    if (rv > iv) return true;
    if (rv < iv) return false;
  }
  return false;
}

/// Renders GitHub-flavoured release notes as plain text for the update dialog.
///
/// The notes are written for a browser, not for a 280dp-wide phone dialog, and
/// the difference was visible on a real device. Two separate problems, both
/// caused by handing the raw body straight to a `Text` widget:
///
///  1. Markup leaked through. `### Fixed` printed its own hash characters, list
///     items printed their `-`, and inline `**bold**` / `` `code` `` printed
///     their delimiters. Only `**` was being stripped, and only globally, so a
///     bullet's leading marker survived.
///  2. The source is hard-wrapped at ~80 columns for readability in
///     CHANGELOG.md. Preserved line breaks split sentences mid-clause — "…
///     was added to\nrevenue." — because `Text` wraps on the newlines it is
///     given as though they were paragraph ends.
///
/// So this does two jobs: it strips the markup, and it *unwraps* the hard
/// wraps, re-joining a continued line onto the bullet or paragraph it belongs
/// to. Section headings are kept, uppercased, because they carry real meaning
/// ("Fixed", "Added") that a flat list would lose.
String formatChangelog(String rawNotes) {
  if (rawNotes.trim().isEmpty) {
    return 'No changelog available for this release.';
  }

  final normalized =
      rawNotes.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();

  final lines = normalized.split('\n');

  // Blocks are flushed in order, so a paragraph is never interleaved with the
  // bullet above it.
  final blocks = <String>[];
  String? openBullet;
  String? openParagraph;

  void flush() {
    if (openBullet != null) {
      final text = _stripInlineMarkdown(openBullet!);
      if (text.isNotEmpty) blocks.add('• $text');
      openBullet = null;
    }
    if (openParagraph != null) {
      final text = _stripInlineMarkdown(openParagraph!);
      if (text.isNotEmpty) blocks.add(text);
      openParagraph = null;
    }
  }

  for (final line in lines) {
    final trimmedRight = line.trimRight();
    final trimmed = trimmedRight.trim();

    // Blank line: ends whatever block was open.
    if (trimmed.isEmpty) {
      flush();
      continue;
    }

    // The generated trailer is GitHub's own boilerplate, not release content.
    // Dropping only its URL would leave a bare "Full Changelog:" line behind.
    if (RegExp(r'^\*\*Full Changelog\*\*').hasMatch(trimmed)) {
      flush();
      continue;
    }

    // A heading starts a new block. `#{1,6}` because GitHub release bodies and
    // the CHANGELOG extraction use `###`.
    final heading = RegExp(r'^#{1,6}\s+(.*)$').firstMatch(trimmed);
    if (heading != null) {
      flush();
      final title = _stripInlineMarkdown(heading.group(1) ?? '').toUpperCase();
      if (title.isNotEmpty) blocks.add(title);
      continue;
    }

    // A list item starts a new bullet. Everything indented under it is a
    // continuation and is appended below.
    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(trimmed);
    if (bullet != null) {
      flush();
      openBullet = bullet.group(1) ?? '';
      continue;
    }

    // A non-indented line with a block already open is a *lazy* continuation:
    // markdown allows the wrap to break before the indent. Append rather than
    // start a new paragraph, joining with a space to undo the hard wrap.
    if (openBullet != null) {
      openBullet = '${openBullet!} $trimmed';
      continue;
    }
    if (openParagraph != null) {
      openParagraph = '${openParagraph!} $trimmed';
      continue;
    }

    // First line of a paragraph.
    openParagraph = trimmed;
  }
  flush();

  if (blocks.isEmpty) {
    return 'No changelog available for this release.';
  }
  return blocks.join('\n\n');
}

/// Removes inline Markdown delimiters, keeping the text they wrap.
///
/// Handles the forms that actually appear in a release body: emphasis, strong
/// emphasis, inline code, and `[label](url)` links. Backtick spans are stripped
/// before emphasis so that `` `x` `` inside a `**bold**` run does not unbalance
/// the surrounding delimiters.
String _stripInlineMarkdown(String input) {
  // The generated trailer carries a compare URL; drop the whole line so its
  // "**Full Changelog**:" label does not survive as stray text.
  var text = input;

  // `[label](url)` becomes `label`. Must run before the bare-URL removal below,
  // otherwise the URL is deleted first and the text is left as "label](".
  text = text.replaceAllMapped(
      RegExp(r'!?\[([^\]]*)\]\([^)]*\)'), (m) => m.group(1) ?? '');

  // Backticks first: a `code` span inside a **bold** run would otherwise
  // unbalance the surrounding `**` and leave one of them behind.
  text = text.replaceAllMapped(RegExp(r'`([^`]*)`'), (m) => m.group(1) ?? '');

  text = text.replaceAllMapped(
      RegExp(r'\*\*\*(.+?)\*\*\*'), (m) => m.group(1) ?? '');
  text =
      text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(
      RegExp(r'(?<!\*)\*([^*\n]+)\*(?!\*)'), (m) => m.group(1) ?? '');
  text = text.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m.group(1) ?? '');

  // Any remaining bare URL is noise in a phone dialog.
  text = text.replaceAll(RegExp(r'https?://\S+'), '');

  // Collapse the runs of spaces left behind by removed markers and by the
  // hard-wrap joins, then trim.
  return text.replaceAll(RegExp(r'[ \t]{2,}'), ' ').trim();
}

Future<void> showUpdateDialog(BuildContext context, UpdateInfo update) async {
  final pkg = await PackageInfo.fromPlatform();
  final installed = pkg.version;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header (fixed) ──
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [AppTheme.teal, AppTheme.tealDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.system_update_rounded,
                size: 26, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('Update Available',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text('v$installed',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('\u2192',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(update.tagName,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.primary)),
            ),
          ]),
          const SizedBox(height: 14),

          // ── Scrollable changelog container ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('What\'s New',
                      style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.05,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 7),
                  // Grow with the notes, up to a cap, instead of a fixed 200.
                  // A fixed box wasted space on a one-line release and still
                  // clipped a long one; now short notes stay compact and long
                  // ones use the available height before scrolling.
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 320),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Text(
                        formatChangelog(update.body),
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.6),
                      ),
                    ),
                  ),
                ]),
          ),

          const SizedBox(height: 16),

          // ── Action buttons (fixed) ──
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                await launchUrl(Uri.parse(AppUpdateConfig.latestReleaseUrl),
                    mode: LaunchMode.externalApplication);
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Update Now',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Remind me later',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ]),
      ),
    ),
  );
}
