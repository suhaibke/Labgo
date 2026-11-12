import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../l10n/app_localizations.dart';
import '../../services/order_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/result_file.dart';

class ResultDetailScreen extends StatefulWidget {
  final Order order;

  const ResultDetailScreen({super.key, required this.order});

  @override
  State<ResultDetailScreen> createState() => _ResultDetailScreenState();
}

class _ResultDetailScreenState extends State<ResultDetailScreen> {
  ResultFile? get _file {
    final url = widget.order.reportUrl;
    if (url == null) return null;
    return ResultFile.fromUrl(url);
  }

  String _patientName() {
    if (widget.order.isForOtherPerson &&
        (widget.order.beneficiaryName?.trim().isNotEmpty ?? false)) {
      return widget.order.beneficiaryName!.trim();
    }
    return widget.order.patientData?['name']?.toString() ?? '';
  }

  // ── Download state ─────────────────────────────────────────────────────────
  bool _isDownloading = false;
  double _downloadProgress = 0; // 0.0 – 1.0
  String? _localPath; // cached file path after first download
  String? _downloadError;

  /// Downloads the file if not already cached, returns local path on success.
  Future<String?> _downloadFile(ResultFile file) async {
    if (_localPath != null) return _localPath;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
      _downloadError = null;
    });

    try {
      final uri = Uri.parse(file.url);
      final request = http.Request('GET', uri);
      final response = await request.send();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int received = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        received += chunk.length;
        if (contentLength > 0 && mounted) {
          setState(() => _downloadProgress = received / contentLength);
        }
      }

      final dir = await getTemporaryDirectory();
      // Derive a safe filename from the URL
      final rawName = uri.pathSegments.last.split('?').first;
      final ext = file.extension.toLowerCase();
      final fileName = rawName.isNotEmpty ? rawName : 'result.$ext';
      final localFile = File('${dir.path}/$fileName');
      await localFile.writeAsBytes(bytes);

      if (mounted) {
        setState(() {
          _localPath = localFile.path;
          _isDownloading = false;
          _downloadProgress = 1;
        });
      }
      return localFile.path;
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadError = e.toString();
        });
      }
      return null;
    }
  }

  Future<void> _openFile() async {
    final file = _file;
    if (file == null) return;
    final path = await _downloadFile(file);
    if (path == null || !mounted) return;
    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done && mounted) {
      _showError(result.message);
    }
  }

  Future<void> _shareFile() async {
    final file = _file;
    if (file == null) return;
    final path = await _downloadFile(file);
    if (path == null || !mounted) return;
    await Share.shareXFiles(
      [XFile(path)],
      text: 'LabGo — ${_patientName()}',
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final file = _file;
    final locale = Localizations.localeOf(context).toString();
    final completedRaw = widget.order.results?['completedAt']?.toString();
    DateTime? completedAt;
    if (completedRaw != null) {
      completedAt = DateTime.tryParse(completedRaw);
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundLavender,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      l10n.testResults,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF5B3CC4),
                      ),
                    ),
                  ),
                  // Share icon in app bar (only when file exists)
                  if (file != null)
                    IconButton(
                      icon: const Icon(Icons.share_rounded, size: 20),
                      color: AppTheme.primaryColor,
                      onPressed: _isDownloading ? null : _shareFile,
                      tooltip: l10n.shareWithOthers,
                    )
                  else
                    const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Content ────────────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  // Info card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE8E0F8)),
                    ),
                    child: Column(
                      children: [
                        _InfoRow(label: l10n.patient, value: _patientName()),
                        _InfoRow(
                          label: l10n.laboratory,
                          value: widget.order.labData?['name']?.toString() ?? '',
                        ),
                        _InfoRow(
                          label: l10n.invoiceTests,
                          value: widget.order.tests.isEmpty
                              ? l10n.invoiceTestsCount(0)
                              : widget.order.tests
                                  .map((t) => t.testName)
                                  .join(' • '),
                        ),
                        _InfoRow(
                          label: l10n.sampleCode,
                          value: widget.order.qrCode,
                        ),
                        _InfoRow(
                          label: l10n.sampleDate,
                          value: DateFormat('d MMMM yyyy', locale).format(
                              (completedAt ?? widget.order.createdAt).toLocal()),
                        ),
                        if (file != null)
                          _InfoRow(
                            label: l10n.resultFile,
                            value: file.extension.isEmpty
                                ? l10n.openResult
                                : file.extension,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // File preview + actions
                  if (file != null)
                    _ResultPreviewCard(
                      file: file,
                      l10n: l10n,
                      isDownloading: _isDownloading,
                      downloadProgress: _downloadProgress,
                      localPath: _localPath,
                      downloadError: _downloadError,
                      onOpen: _openFile,
                      onShare: _shareFile,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info row
// ─────────────────────────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF9A93B0),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '—' : value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Color(0xFF1C1433),
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File preview card with download progress + open + share
// ─────────────────────────────────────────────────────────────────────────────
class _ResultPreviewCard extends StatelessWidget {
  final ResultFile file;
  final AppLocalizations l10n;
  final bool isDownloading;
  final double downloadProgress;
  final String? localPath;
  final String? downloadError;
  final VoidCallback onOpen;
  final VoidCallback onShare;

  const _ResultPreviewCard({
    required this.file,
    required this.l10n,
    required this.isDownloading,
    required this.downloadProgress,
    required this.localPath,
    required this.downloadError,
    required this.onOpen,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Thumbnail / placeholder ────────────────────────────────────────
        GestureDetector(
          onTap: isDownloading ? null : onOpen,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 180),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE8E0F8)),
            ),
            clipBehavior: Clip.antiAlias,
            child: switch (file.kind) {
              ResultFileKind.image => CachedNetworkImage(
                  imageUrl: file.url,
                  height: 260,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => const SizedBox(
                    height: 180,
                    child: Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.primaryColor),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _FilePlaceholder(
                    icon: Icons.broken_image_outlined,
                    title: l10n.failedToLoadImage,
                    subtitle: l10n.openResult,
                  ),
                ),
              ResultFileKind.pdf => _FilePlaceholder(
                  icon: Icons.picture_as_pdf_rounded,
                  iconColor: AppTheme.error,
                  title: 'PDF',
                  subtitle: l10n.openResult,
                ),
              ResultFileKind.other => _FilePlaceholder(
                  icon: Icons.insert_drive_file_rounded,
                  title: file.extension.isEmpty ? l10n.resultFile : file.extension,
                  subtitle: l10n.openResult,
                ),
            },
          ),
        ),

        const SizedBox(height: 12),

        // ── Download progress bar (shown while downloading) ────────────────
        if (isDownloading) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: downloadProgress > 0 ? downloadProgress : null,
              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              color: AppTheme.primaryColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            downloadProgress > 0
                ? '${(downloadProgress * 100).toStringAsFixed(0)}%'
                : '...',
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Error message ──────────────────────────────────────────────────
        if (downloadError != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: AppTheme.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    downloadError!,
                    style: const TextStyle(fontSize: 12, color: AppTheme.error),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // ── Action buttons ─────────────────────────────────────────────────
        Row(
          children: [
            // Open button
            Expanded(
              flex: 3,
              child: _ActionButton(
                onTap: isDownloading ? null : onOpen,
                icon: localPath != null
                    ? Icons.open_in_new_rounded
                    : Icons.download_rounded,
                label: localPath != null ? l10n.openResult : l10n.downloadResult,
                isPrimary: true,
                isLoading: isDownloading,
              ),
            ),
            const SizedBox(width: 10),
            // Share button
            Expanded(
              flex: 2,
              child: _ActionButton(
                onTap: isDownloading ? null : onShare,
                icon: Icons.share_rounded,
                label: l10n.shareWithOthers,
                isPrimary: false,
                isLoading: false,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final VoidCallback? onTap;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final bool isLoading;

  const _ActionButton({
    required this.onTap,
    required this.icon,
    required this.label,
    required this.isPrimary,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary ? AppTheme.primaryColor : const Color(0xFFF3EDFF);
    final fg = isPrimary ? Colors.white : AppTheme.primaryColor;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            boxShadow: isPrimary
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 17,
                  height: 17,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              else
                Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// File placeholder (for PDF / non-image files)
// ─────────────────────────────────────────────────────────────────────────────
class _FilePlaceholder extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;

  const _FilePlaceholder({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: (iconColor ?? AppTheme.primaryColor)
                  .withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                size: 32, color: iconColor ?? AppTheme.primaryColor),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1433),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A93B0),
            ),
          ),
        ],
      ),
    );
  }
}

