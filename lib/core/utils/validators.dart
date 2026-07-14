/// MekaarValidators — Kumpulan validator input terpusat.
/// Dipakai oleh semua form field di app (login, register, add_guardian, etc.)
class MekaarValidators {
  MekaarValidators._();

  // ─────────────────────────────────────────
  // Email
  // ─────────────────────────────────────────
  static String? email(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email tidak boleh kosong';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format email tidak valid';
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Password
  // ─────────────────────────────────────────
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password tidak boleh kosong';
    }
    if (value.length < 6) {
      return 'Password minimal 6 karakter';
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Username
  // ─────────────────────────────────────────
  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Username tidak boleh kosong';
    }
    if (value.trim().length < 3) {
      return 'Username minimal 3 karakter';
    }
    if (value.trim().length > 30) {
      return 'Username maksimal 30 karakter';
    }
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(value.trim())) {
      return 'Username hanya boleh huruf, angka, dan underscore';
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Email atau Username (untuk add guardian / new chat)
  // ─────────────────────────────────────────
  static String? emailOrUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Input tidak boleh kosong';
    }
    // Jika mengandung @, validasi sebagai email
    if (value.contains('@')) {
      return email(value);
    }
    // Jika tidak ada @, validasi sebagai username
    return username(value);
  }

  // ─────────────────────────────────────────
  // PIN
  // ─────────────────────────────────────────
  static String? pin(String? value) {
    if (value == null || value.isEmpty) {
      return 'PIN tidak boleh kosong';
    }
    if (value.length != 6) {
      return 'PIN harus tepat 6 digit';
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      return 'PIN hanya boleh berisi angka';
    }
    return null;
  }

  // ─────────────────────────────────────────
  // Required (generik)
  // ─────────────────────────────────────────
  static String? required(String? value, {String fieldName = 'Field ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName tidak boleh kosong';
    }
    return null;
  }
}
