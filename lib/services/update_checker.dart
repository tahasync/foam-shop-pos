import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class AppUpdateConfig {
  static const repoOwner = 'tahasync';
  static const repoName = 'foam-shop-pos';
  static const apiUrl = 'https://api.github.com/repos/$repoOwner/$repoName/releases/latest';
  static const latestReleaseUrl = 'https://github.com/$repoOwner/$repoName/releases/latest';
  static const downloadUrl = 'https://github.com/$repoOwner/$repoName/releases/download';
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
    return UpdateInfo(tagName: tag, htmlUrl: url, body: body, publishedAt: published ?? DateTime.now());
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

String formatChangelog(String rawNotes) {
  if (rawNotes.isEmpty) {
    return 'No changelog available for this release.';
  }
  final clean = rawNotes
      .replaceAll(RegExp(r'\*\*Full Changelog\*\*:\s*https?://\S+'), '')
      .replaceAll(RegExp(r'https?://github\.com/\S+'), '')
      .replaceAll(RegExp(r'\*\*'), '')
      .trim();
  if (clean.isEmpty) {
    return 'No changelog available for this release.';
  }
  return clean;
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
            width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.teal, AppTheme.tealDark]),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.system_update_rounded, size: 26, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text('Update Available', style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800, fontSize: 17)),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              ),
              child: Text('v$installed', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text('\u2192', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(update.tagName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
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
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('What\'s New', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                  letterSpacing: 0.05, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const SizedBox(height: 7),
              SizedBox(
                height: 200,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    formatChangelog(update.body),
                    style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface, height: 1.6),
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
                await launchUrl(Uri.parse(AppUpdateConfig.latestReleaseUrl), mode: LaunchMode.externalApplication);
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.download_rounded, size: 16),
              label: const Text('Update Now', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Remind me later', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ),
        ]),
      ),
    ),
  );
}
