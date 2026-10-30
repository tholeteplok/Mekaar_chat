import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';
import '../utils/link_risk.dart';
import 'mekaar_snackbar.dart';

/// Regex standar deteksi tautan (http, https, dan www)
final RegExp _urlRegex = RegExp(
  r'(https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|www\.[a-zA-Z0-9][a-zA-Z0-9-]+[a-zA-Z0-9]\.[^\s]{2,}|https?:\/\/[^\s]+)',
  caseSensitive: false,
);

/// Dialog konfirmasi keamanan anti-phishing / anti-drainer sebelum membuka tautan eksternal.
Future<void> showMekaarLinkConfirmationDialog(
  BuildContext context,
  String rawUrl,
) async {
  final assessment = assessLink(rawUrl);
  if (assessment.isHighRisk) {
    HapticService.trigger(MekaarHapticIntent.warning);
  } else {
    HapticService.trigger(MekaarHapticIntent.selection);
  }

  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = MekaarColors.surfaceOf(context);
  final textPrimary = MekaarColors.textPrimaryOf(context);
  final textMuted = MekaarColors.textMutedOf(context);
  final primary = MekaarColors.primaryOf(context);

  final Color headerColor;
  final IconData headerIcon;
  final String headerTitle;

  if (assessment.isBlocked) {
    headerColor = MekaarColors.sosRed;
    headerIcon = SolarIconsOutline.dangerCircle;
    headerTitle = 'Tautan Berbahaya / Diblokir';
  } else if (assessment.isHighRisk) {
    headerColor = MekaarColors.warnAmber;
    headerIcon = SolarIconsOutline.shieldWarning;
    headerTitle = 'Peringatan Keamanan Tautan';
  } else {
    headerColor = primary;
    headerIcon = SolarIconsOutline.linkCircle;
    headerTitle = 'Buka Tautan Eksternal';
  }

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: MekaarColors.borderOf(
              ctx,
            ).withValues(alpha: isDark ? 0.3 : 0.15),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: headerColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: headerColor, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      headerTitle,
                      style: MekaarTypography.headingSM.copyWith(
                        color: textPrimary,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                assessment.isBlocked
                    ? 'Tautan ini mengandung skema protokol yang tidak diizinkan:'
                    : 'Anda akan meninggalkan aplikasi MEKAAR menuju domain:',
                style: MekaarTypography.bodySM.copyWith(
                  color: textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MekaarColors.borderOf(ctx).withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assessment.host,
                            style: MekaarTypography.bodySM.copyWith(
                              color: textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            assessment.normalizedUrl,
                            style: MekaarTypography.labelSM.copyWith(
                              color: textMuted,
                              fontSize: 11,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(SolarIconsOutline.copy, size: 18),
                      tooltip: 'Salin Tautan',
                      color: primary,
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: assessment.normalizedUrl),
                        );
                        if (context.mounted) {
                          MekaarSnackbar.success(context, 'Tautan disalin');
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (assessment.risks.isNotEmpty) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: assessment.risks.map((risk) {
                    final isHigh =
                        risk == LinkRisk.punycode ||
                        risk == LinkRisk.userInfo ||
                        risk == LinkRisk.blockedScheme;
                    final warnColor = isHigh
                        ? MekaarColors.sosCoral
                        : MekaarColors.warnAmber;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            SolarIconsOutline.dangerTriangle,
                            size: 15,
                            color: warnColor,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              LinkAssessment.descriptionOf(
                                risk,
                                port: assessment.uri?.port,
                              ),
                              style: MekaarTypography.labelSM.copyWith(
                                color: warnColor,
                                fontSize: 11,
                                height: 1.3,
                                fontWeight: isHigh
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      SolarIconsOutline.shieldCheck,
                      size: 16,
                      color: MekaarColors.safeTeal,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Pastikan Anda mempercayai situs ini untuk menghindari potensi penipuan atau phishing.',
                        style: MekaarTypography.labelSM.copyWith(
                          color: textMuted,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text(
                      'Batal',
                      style: TextStyle(
                        color: textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (assessment.isBlocked)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.08),
                        foregroundColor: textMuted,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(
                        SolarIconsOutline.forbiddenCircle,
                        size: 16,
                      ),
                      label: const Text('Tautan Diblokir'),
                      onPressed: null,
                    )
                  else if (assessment.isHighRisk)
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: MekaarColors.sosCoral,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(
                        SolarIconsOutline.arrowRightUp,
                        size: 16,
                      ),
                      label: const Text('Tetap Buka'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (assessment.uri != null &&
                            (assessment.uri!.scheme == 'http' ||
                                assessment.uri!.scheme == 'https')) {
                          try {
                            await launchUrl(
                              assessment.uri!,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            await launchUrl(
                              assessment.uri!,
                              mode: LaunchMode.platformDefault,
                            );
                          }
                        }
                      },
                    )
                  else
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      icon: const Icon(
                        SolarIconsOutline.arrowRightUp,
                        size: 16,
                      ),
                      label: const Text('Buka Tautan'),
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        if (assessment.uri != null &&
                            (assessment.uri!.scheme == 'http' ||
                                assessment.uri!.scheme == 'https')) {
                          try {
                            await launchUrl(
                              assessment.uri!,
                              mode: LaunchMode.externalApplication,
                            );
                          } catch (_) {
                            await launchUrl(
                              assessment.uri!,
                              mode: LaunchMode.platformDefault,
                            );
                          }
                        }
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Widget perender teks dengan deteksi tautan otomatis (hyperlink)
/// serta dukungan penandaan sorotan kata (highlighting) saat mode pencarian aktif.
class MekaarLinkText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final Color? linkColor;
  final bool isMe;
  final String? highlightQuery;

  const MekaarLinkText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.linkColor,
    this.isMe = false,
    this.highlightQuery,
  });

  @override
  State<MekaarLinkText> createState() => _MekaarLinkTextState();
}

class _MekaarLinkTextState extends State<MekaarLinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
    super.dispose();
  }

  /// Memecah string menjadi daftar InlineSpan dengan latar belakang sorotan (highlight)
  /// pada segmen yang cocok dengan kueri pencarian (case-insensitive).
  List<InlineSpan> _buildHighlightedSpans({
    required String text,
    required TextStyle style,
    required String? highlightQuery,
    GestureRecognizer? recognizer,
  }) {
    final query = highlightQuery?.trim();
    if (query == null || query.isEmpty) {
      return [TextSpan(text: text, style: style, recognizer: recognizer)];
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    if (!lowerText.contains(lowerQuery)) {
      return [TextSpan(text: text, style: style, recognizer: recognizer)];
    }

    final spans = <InlineSpan>[];
    int start = 0;
    final highlightStyle = style.copyWith(
      backgroundColor: MekaarColors.warnAmber.withValues(alpha: 0.35),
    );

    while (start < text.length) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index == -1) {
        spans.add(
          TextSpan(
            text: text.substring(start),
            style: style,
            recognizer: recognizer,
          ),
        );
        break;
      }

      if (index > start) {
        spans.add(
          TextSpan(
            text: text.substring(start, index),
            style: style,
            recognizer: recognizer,
          ),
        );
      }

      spans.add(
        TextSpan(
          text: text.substring(index, index + query.length),
          style: highlightStyle,
          recognizer: recognizer,
        ),
      );

      start = index + query.length;
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      if (widget.highlightQuery != null &&
          widget.highlightQuery!.trim().isNotEmpty) {
        final spans = _buildHighlightedSpans(
          text: widget.text,
          style: widget.baseStyle,
          highlightQuery: widget.highlightQuery,
        );
        return Text.rich(TextSpan(children: spans), style: widget.baseStyle);
      }
      return Text(widget.text, style: widget.baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    final effectiveLinkColor =
        widget.linkColor ?? (widget.isMe ? Colors.white : MekaarColors.cyan);

    final linkStyle = widget.baseStyle.copyWith(
      color: effectiveLinkColor,
      decoration: TextDecoration.underline,
      decorationColor: effectiveLinkColor.withValues(alpha: 0.8),
      fontWeight: FontWeight.w600,
    );

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        final nonLinkText = widget.text.substring(lastMatchEnd, match.start);
        spans.addAll(
          _buildHighlightedSpans(
            text: nonLinkText,
            style: widget.baseStyle,
            highlightQuery: widget.highlightQuery,
          ),
        );
      }

      final urlString = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          showMekaarLinkConfirmationDialog(context, urlString);
        };
      _recognizers.add(recognizer);

      spans.addAll(
        _buildHighlightedSpans(
          text: urlString,
          style: linkStyle,
          highlightQuery: widget.highlightQuery,
          recognizer: recognizer,
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < widget.text.length) {
      final remainingText = widget.text.substring(lastMatchEnd);
      spans.addAll(
        _buildHighlightedSpans(
          text: remainingText,
          style: widget.baseStyle,
          highlightQuery: widget.highlightQuery,
        ),
      );
    }

    return Text.rich(TextSpan(children: spans), style: widget.baseStyle);
  }
}
