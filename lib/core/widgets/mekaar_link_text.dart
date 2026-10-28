import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../constants/typography.dart';
import '../services/haptic_service.dart';

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
  HapticService.trigger(MekaarHapticIntent.selection);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final surface = MekaarColors.surfaceOf(context);
  final textPrimary = MekaarColors.textPrimaryOf(context);
  final textMuted = MekaarColors.textMutedOf(context);
  final primary = MekaarColors.primaryOf(context);

  final normalizedUrl = rawUrl.startsWith(RegExp(r'https?:\/\/', caseSensitive: false))
      ? rawUrl
      : 'https://$rawUrl';
  final uri = Uri.tryParse(normalizedUrl);
  final host = uri?.host.isNotEmpty == true ? uri!.host : rawUrl;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return Dialog(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: MekaarColors.borderOf(ctx).withValues(alpha: isDark ? 0.3 : 0.15),
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
                      color: primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      SolarIconsOutline.linkCircle,
                      color: primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Buka Tautan Eksternal',
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
                'Anda akan meninggalkan aplikasi MEKAAR menuju domain:',
                style: MekaarTypography.bodySM.copyWith(
                  color: textMuted,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: MekaarColors.borderOf(ctx).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      host,
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
                      normalizedUrl,
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    SolarIconsOutline.shieldWarning,
                    size: 16,
                    color: MekaarColors.warnAmber,
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
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    icon: const Icon(SolarIconsOutline.arrowRightUp, size: 16),
                    label: const Text('Buka Tautan'),
                    onPressed: () async {
                      Navigator.of(ctx).pop();
                      if (uri != null) {
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          await launchUrl(uri, mode: LaunchMode.platformDefault);
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
class MekaarLinkText extends StatefulWidget {
  final String text;
  final TextStyle baseStyle;
  final Color? linkColor;
  final bool isMe;

  const MekaarLinkText({
    super.key,
    required this.text,
    required this.baseStyle,
    this.linkColor,
    this.isMe = false,
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

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final matches = _urlRegex.allMatches(widget.text).toList();
    if (matches.isEmpty) {
      return Text(widget.text, style: widget.baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    final effectiveLinkColor = widget.linkColor ??
        (widget.isMe ? Colors.white : MekaarColors.cyan);

    final linkStyle = widget.baseStyle.copyWith(
      color: effectiveLinkColor,
      decoration: TextDecoration.underline,
      decorationColor: effectiveLinkColor.withValues(alpha: 0.8),
      fontWeight: FontWeight.w600,
    );

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(
          TextSpan(
            text: widget.text.substring(lastMatchEnd, match.start),
            style: widget.baseStyle,
          ),
        );
      }

      final urlString = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () {
          showMekaarLinkConfirmationDialog(context, urlString);
        };
      _recognizers.add(recognizer);

      spans.add(
        TextSpan(
          text: urlString,
          style: linkStyle,
          recognizer: recognizer,
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(lastMatchEnd),
          style: widget.baseStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: widget.baseStyle,
    );
  }
}
