/// Jenis risiko keamanan yang terdeteksi pada tautan eksternal (anti-phishing).
enum LinkRisk {
  insecureHttp,
  punycode,
  ipAddressHost,
  userInfo,
  shortener,
  nonStandardPort,
  veryLong,
  blockedScheme,
}

/// Kumpulan domain pemendek tautan umum yang sering digunakan untuk menyamarkan URL phishing.
const Set<String> kCommonLinkShorteners = {
  'bit.ly',
  'tinyurl.com',
  't.co',
  'goo.gl',
  'is.gd',
  'cutt.ly',
  'rebrand.ly',
  'shorturl.at',
  'v.gd',
  'ow.ly',
  'buff.ly',
};

/// Hasil analisis risiko tautan.
class LinkAssessment {
  final Uri? uri;
  final String rawUrl;
  final String normalizedUrl;
  final String host;
  final List<LinkRisk> risks;
  final bool isBlocked;

  const LinkAssessment({
    required this.uri,
    required this.rawUrl,
    required this.normalizedUrl,
    required this.host,
    required this.risks,
    required this.isBlocked,
  });

  /// Menandakan apakah tautan berisiko tinggi (penyamaran domain, manipulasi kredensial, atau skema terlarang).
  bool get isHighRisk =>
      risks.contains(LinkRisk.punycode) ||
      risks.contains(LinkRisk.userInfo) ||
      risks.contains(LinkRisk.blockedScheme);

  /// Label deskripsi peringatan dalam Bahasa Indonesia yang ringkas dan jelas.
  static String descriptionOf(LinkRisk risk, {int? port}) {
    switch (risk) {
      case LinkRisk.insecureHttp:
        return 'Koneksi tidak terenkripsi (HTTP), data dapat diintip di jaringan publik.';
      case LinkRisk.punycode:
        return 'Alamat memakai karakter khusus (punycode) dan berpotensi menyamar sebagai situs resmi.';
      case LinkRisk.ipAddressHost:
        return 'Alamat berupa IP langsung, bukan nama domain situs yang sah.';
      case LinkRisk.userInfo:
        return 'Alamat memuat nama pengguna/kredensial sebelum domain — indikasi kuat phishing.';
      case LinkRisk.shortener:
        return 'Tautan pendek menyembunyikan domain tujuan asli.';
      case LinkRisk.nonStandardPort:
        return port != null
            ? 'Tautan menggunakan port non-standar ($port).'
            : 'Tautan menggunakan port non-standar.';
      case LinkRisk.veryLong:
        return 'Tautan sangat panjang (>300 karakter), berpotensi menyembunyikan parameter manipulatif.';
      case LinkRisk.blockedScheme:
        return 'Protokol tautan tidak didukung dan berisiko mengeksploitasi sistem perangkat. Diblokir demi keamanan.';
    }
  }
}

/// Mengevaluasi risiko keamanan sebuah string tautan secara deterministik dan murni lokal.
LinkAssessment assessLink(String rawUrl) {
  final trimmed = rawUrl.trim();
  final lower = trimmed.toLowerCase();

  // 1. Periksa protokol/skema berbahaya yang dilarang keras
  final blockedPrefixes = [
    'javascript:',
    'file:',
    'intent:',
    'content:',
    'blob:',
    'about:',
    'chrome:',
    'vbs:',
    'vbscript:',
  ];

  for (final prefix in blockedPrefixes) {
    if (lower.startsWith(prefix)) {
      return LinkAssessment(
        uri: null,
        rawUrl: trimmed,
        normalizedUrl: trimmed,
        host: trimmed,
        risks: const [LinkRisk.blockedScheme],
        isBlocked: true,
      );
    }
  }

  // 2. Normalisasi skema web HTTP/HTTPS
  String normalizedUrl;
  if (RegExp(r'^https?:\/\/', caseSensitive: false).hasMatch(trimmed)) {
    normalizedUrl = trimmed;
  } else {
    // Jika ada skema lain yang tidak dikenal (misal tel:, mailto:, sms:, market:)
    final colonIdx = trimmed.indexOf(':');
    final slashIdx = trimmed.indexOf('/');
    if (colonIdx != -1 && (slashIdx == -1 || colonIdx < slashIdx)) {
      // Skema non-HTTP terdeteksi
      return LinkAssessment(
        uri: null,
        rawUrl: trimmed,
        normalizedUrl: trimmed,
        host: trimmed,
        risks: const [LinkRisk.blockedScheme],
        isBlocked: true,
      );
    }
    normalizedUrl = 'https://$trimmed';
  }

  final uri = Uri.tryParse(normalizedUrl);
  if (uri == null || uri.host.isEmpty) {
    return LinkAssessment(
      uri: uri,
      rawUrl: trimmed,
      normalizedUrl: normalizedUrl,
      host: trimmed,
      risks: const [LinkRisk.blockedScheme],
      isBlocked: true,
    );
  }

  // Hanya skema http dan https yang diizinkan untuk dibuka
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return LinkAssessment(
      uri: uri,
      rawUrl: trimmed,
      normalizedUrl: normalizedUrl,
      host: uri.host,
      risks: const [LinkRisk.blockedScheme],
      isBlocked: true,
    );
  }

  final risks = <LinkRisk>[];

  // Insecure HTTP
  if (uri.scheme == 'http') {
    risks.add(LinkRisk.insecureHttp);
  }

  final hostLower = uri.host.toLowerCase();

  // Punycode (IDN homograph attack, misal xn--pple-43d.com)
  final labels = hostLower.split('.');
  if (labels.any((part) => part.startsWith('xn--'))) {
    risks.add(LinkRisk.punycode);
  }

  // IP Address host (IPv4 atau IPv6)
  final isIpv4 = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(hostLower);
  final isIpv6 = hostLower.contains(':') || hostLower.startsWith('[');
  if (isIpv4 || isIpv6) {
    risks.add(LinkRisk.ipAddressHost);
  }

  // UserInfo (misal https://target.com@evil.com)
  if (uri.userInfo.isNotEmpty) {
    risks.add(LinkRisk.userInfo);
  }

  // Shortener
  if (kCommonLinkShorteners.contains(hostLower)) {
    risks.add(LinkRisk.shortener);
  }

  // Non-standard port
  if (uri.hasPort && uri.port != 80 && uri.port != 443) {
    risks.add(LinkRisk.nonStandardPort);
  }

  // Very long URL (>300 chars)
  if (trimmed.length > 300) {
    risks.add(LinkRisk.veryLong);
  }

  return LinkAssessment(
    uri: uri,
    rawUrl: trimmed,
    normalizedUrl: normalizedUrl,
    host: uri.host,
    risks: risks,
    isBlocked: false,
  );
}
