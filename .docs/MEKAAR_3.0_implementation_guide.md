# MEKAAR 3.0 — Implementation Guide

## 📋 Overview

This guide provides a comprehensive roadmap for developing MEKAAR 3.0 based on the design specifications and UI/UX mockups. It bridges the gap between the design system and actual code implementation.

---

## 🏗️ Tech Stack Summary

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Frontend** | Flutter (Dart) | Cross-platform mobile app (iOS/Android) |
| **Backend** | Supabase | Authentication, Database, Realtime, Storage |
| **Database** | PostgreSQL (Supabase) | Data persistence with RLS |
| **Maps** | OpenStreetMap + flutter_map | Location display and navigation |
| **Push Notifications** | FCM (Android) + APNs (iOS) | Delivery channel for alerts |
| **Video/Audio** | WebRTC (via Flutter) | P2P streaming with E2EE |
| **State Management** | Provider / Riverpod / Bloc | Application state |

---

## 📁 Project Structure

```
mekaar_app/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── colors.dart
│   │   │   ├── typography.dart
│   │   │   └── themes.dart
│   │   ├── routes/
│   │   │   └── app_routes.dart
│   │   ├── utils/
│   │   │   ├── validators.dart
│   │   │   ├── permissions.dart
│   │   │   └── logger.dart
│   │   └── widgets/
│   │       ├── sos_button.dart
│   │       ├── avatar.dart
│   │       ├── chat_bubble.dart
│   │       └── custom_app_bar.dart
│   ├── data/
│   │   ├── models/
│   │   │   ├── user_model.dart
│   │   │   ├── message_model.dart
│   │   │   ├── guardian_model.dart
│   │   │   ├── sos_session_model.dart
│   │   │   └── security_log_model.dart
│   │   ├── repositories/
│   │   │   ├── auth_repository.dart
│   │   │   ├── chat_repository.dart
│   │   │   ├── guardian_repository.dart
│   │   │   ├── sos_repository.dart
│   │   │   └── log_repository.dart
│   │   └── services/
│   │       ├── supabase_service.dart
│   │       ├── notification_service.dart
│   │       ├── location_service.dart
│   │       ├── audio_service.dart
│   │       ├── video_service.dart
│   │       └── encryption_service.dart
│   ├── features/
│   │   ├── auth/
│   │   │   ├── screens/
│   │   │   │   ├── splash_screen.dart
│   │   │   │   ├── onboarding_screen.dart
│   │   │   │   ├── login_screen.dart
│   │   │   │   └── pin_screen.dart
│   │   │   └── providers/
│   │   │       └── auth_provider.dart
│   │   ├── chat/
│   │   │   ├── screens/
│   │   │   │   ├── chat_list_screen.dart
│   │   │   │   ├── chat_screen.dart
│   │   │   │   └── chat_search_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── chat_item.dart
│   │   │   │   ├── message_bubble.dart
│   │   │   │   ├── message_input.dart
│   │   │   │   └── message_reply.dart
│   │   │   └── providers/
│   │   │       └── chat_provider.dart
│   │   ├── guardian/
│   │   │   ├── screens/
│   │   │   │   ├── guardian_list_screen.dart
│   │   │   │   ├── add_guardian_screen.dart
│   │   │   │   ├── guardian_detail_screen.dart
│   │   │   │   └── swap_guardian_screen.dart
│   │   │   └── widgets/
│   │   │       └── guardian_card.dart
│   │   ├── sos/
│   │   │   ├── screens/
│   │   │   │   ├── sos_active_screen.dart
│   │   │   │   ├── video_emergency_screen.dart
│   │   │   │   └── device_lost_screen.dart
│   │   │   ├── widgets/
│   │   │   │   ├── sos_overlay.dart
│   │   │   │   └── sos_timer.dart
│   │   │   └── providers/
│   │   │       └── sos_provider.dart
│   │   ├── settings/
│   │   │   ├── screens/
│   │   │   │   ├── settings_screen.dart
│   │   │   │   ├── security_logs_screen.dart
│   │   │   │   ├── profile_screen.dart
│   │   │   │   └── notification_screen.dart
│   │   │   └── widgets/
│   │   │       └── settings_tile.dart
│   │   └── map/
│   │       ├── screens/
│   │       │   └── location_map_screen.dart
│   │       └── widgets/
│   │           └── map_marker.dart
│   ├── l10n/                    # Internationalization
│   └── generated/               # Code generation
├── assets/
│   ├── fonts/
│   │   └── PlusJakartaSans/
│   ├── images/
│   └── translations/
├── supabase/
│   └── migrations/              # Database migrations
├── android/                     # Android-specific
├── ios/                         # iOS-specific
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

---

## 🔧 Phase 1: Project Setup & Infrastructure

### 1.1 Initialize Flutter Project

```bash
flutter create mekaar_app --org com.mekaar
cd mekaar_app
```

### 1.2 Add Dependencies

```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  
  # Supabase
  supabase_flutter: ^1.10.0
  supabase: ^1.10.0
  
  # State Management
  provider: ^6.0.5
  riverpod: ^2.4.0
  flutter_riverpod: ^2.4.0
  
  # UI Components
  flutter_svg: ^2.0.7
  google_fonts: ^6.1.0
  shimmer: ^3.0.0
  
  # Maps
  flutter_map: ^6.1.0
  latlong2: ^0.9.0
  
  # Location & Permissions
  location: ^5.0.3
  permission_handler: ^11.0.1
  
  # Audio/Video
  audio_streamer: ^1.0.0
  flutter_webrtc: ^0.9.0
  
  # Storage
  shared_preferences: ^2.2.2
  sqflite: ^2.3.0
  path_provider: ^2.1.0
  
  # Notifications
  firebase_messaging: ^14.6.9
  flutter_local_notifications: ^15.1.1
  
  # Security
  cryptography: ^2.3.0
  flutter_secure_storage: ^9.0.0
  biometric_storage: ^5.0.0
  
  # Utilities
  intl: ^0.18.1
  url_launcher: ^6.2.0
  connectivity_plus: ^5.0.1
  device_info_plus: ^9.1.0
  package_info_plus: ^4.2.0
  
  # Logging
  logger: ^1.4.0
  
  # Code Generation
  json_annotation: ^4.8.1
  freezed_annotation: ^2.4.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.6
  json_serializable: ^6.7.1
  freezed: ^2.4.5
```

### 1.3 Supabase Setup

**1. Create Supabase Project:**
- Go to [supabase.com](https://supabase.com)
- Create new project
- Note: Project URL and anon/public keys

**2. Initialize Supabase in Flutter:**

```dart
// lib/core/supabase_client.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: 'YOUR_SUPABASE_URL',
      anonKey: 'YOUR_ANON_KEY',
      // Optional: add storage bucket
      storageOptions: const StorageOptions(
        bucketName: 'mekaar-media',
      ),
    );
  }
  
  static SupabaseClient get client => Supabase.instance.client;
}
```

### 1.4 Database Schema Implementation

**Run these migrations in Supabase SQL Editor:**

```sql
-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. Profiles table
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  username TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  pin_hash TEXT NOT NULL,
  pin_locked_until TIMESTAMPTZ,
  full_name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 3. Guardian relationships
CREATE TABLE guardians (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  owner_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  guardian_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  permissions JSONB NOT NULL DEFAULT '{"gps": false, "mic": false, "video": false}',
  storage_option TEXT DEFAULT 'stream_only',
  status TEXT DEFAULT 'pending',
  expires_at TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days'),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE(owner_id, guardian_id)
);

-- 4. Chat rooms
CREATE TABLE chat_rooms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_type TEXT NOT NULL CHECK (room_type IN ('normal', 'guardian', 'self_device')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 5. Room participants
CREATE TABLE room_participants (
  room_id UUID REFERENCES chat_rooms(id) ON DELETE CASCADE,
  profile_id UUID REFERENCES profiles(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ DEFAULT now(),
  last_read_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (room_id, profile_id)
);

-- 6. Messages
CREATE TABLE messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  room_id UUID NOT NULL REFERENCES chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT,
  media_url TEXT,
  msg_type TEXT DEFAULT 'text' CHECK (msg_type IN ('text', 'image', 'voice', 'video', 'system', 'location')),
  is_view_once BOOLEAN DEFAULT FALSE,
  reply_to_id UUID REFERENCES messages(id) NULL,
  is_deleted BOOLEAN DEFAULT FALSE,
  auto_delete_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- 7. SOS Sessions
CREATE TABLE sos_sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  guardian_id UUID REFERENCES profiles(id) NULL,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'ended', 'auto_ended')),
  gps_enabled BOOLEAN DEFAULT true,
  mic_enabled BOOLEAN DEFAULT false,
  video_enabled BOOLEAN DEFAULT false,
  ended_reason TEXT CHECK (ended_reason IN ('manual', 'timer', 'inactivity')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 8. Location pings
CREATE TABLE location_pings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id UUID NOT NULL REFERENCES sos_sessions(id) ON DELETE CASCADE,
  latitude DECIMAL(10,7) NOT NULL,
  longitude DECIMAL(10,7) NOT NULL,
  accuracy DECIMAL(5,2),
  timestamp TIMESTAMPTZ DEFAULT now()
);

-- 9. Security logs (PERMANENT)
CREATE TABLE security_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  event_type TEXT NOT NULL,
  details JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  deleted_at TIMESTAMPTZ NULL
);

-- 10. Indexes
CREATE INDEX idx_messages_room_id ON messages(room_id);
CREATE INDEX idx_messages_sender_id ON messages(sender_id);
CREATE INDEX idx_location_pings_session_id ON location_pings(session_id);
CREATE INDEX idx_sos_sessions_user_id ON sos_sessions(user_id);
CREATE INDEX idx_security_logs_user_id ON security_logs(user_id);
CREATE INDEX idx_guardians_owner_id ON guardians(owner_id);
CREATE INDEX idx_guardians_guardian_id ON guardians(guardian_id);
CREATE INDEX idx_room_participants_profile_id ON room_participants(profile_id);

-- 11. Row Level Security (RLS)
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE guardians ENABLE ROW LEVEL SECURITY;
ALTER TABLE chat_rooms ENABLE ROW LEVEL SECURITY;
ALTER TABLE room_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE sos_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE location_pings ENABLE ROW LEVEL SECURITY;
ALTER TABLE security_logs ENABLE ROW LEVEL SECURITY;

-- 12. RLS Policies
-- Profiles: Users can read/write their own profile
CREATE POLICY "Users can manage own profile" ON profiles
  USING (auth.uid() = id);
  
-- Guardians: Users can manage their guardians
CREATE POLICY "Users can manage their guardians" ON guardians
  USING (auth.uid() = owner_id);
  
-- Messages: Only participants can read messages in a room
CREATE POLICY "Users can read messages in their rooms" ON messages
  USING (
    EXISTS (
      SELECT 1 FROM room_participants 
      WHERE room_id = messages.room_id 
      AND profile_id = auth.uid()
    )
  );

-- Security logs: Only owner can read
CREATE POLICY "Users can read own logs" ON security_logs
  USING (auth.uid() = user_id);
```

---

## 🎨 Phase 2: UI Implementation

### 2.1 Design System Setup

**Colors (lib/core/constants/colors.dart):**

```dart
import 'package:flutter/material.dart';

class MekaarColors {
  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);
  
  // SOS Accent
  static const Color sosAccent = Color(0xFFE11D48);
  static const Color sosLight = Color(0xFFFFF1F2);
  static const Color sosRed = Color(0xFFEF4444);
  
  // Guardian
  static const Color guardian = Color(0xFF7C3AED);
  static const Color guardianLight = Color(0xFFF3E8FF);
  
  // Status
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFEFF6FF);
  
  // Surface
  static const Color background = Color(0xFFFAFBFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surface2 = Color(0xFFF4F6F8);
  static const Color surface3 = Color(0xFFEAEEF2);
  
  // Borders
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderLight = Color(0xFFF1F5F9);
}

class MekaarTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: MekaarColors.sosAccent,
      scaffoldBackgroundColor: MekaarColors.background,
      colorScheme: const ColorScheme.light(
        primary: MekaarColors.sosAccent,
        secondary: MekaarColors.guardian,
        tertiary: MekaarColors.success,
        surface: MekaarColors.surface,
        surfaceVariant: MekaarColors.surface2,
        error: MekaarColors.sosRed,
        onPrimary: Colors.white,
        onSurface: MekaarColors.textPrimary,
      ),
      fontFamily: 'PlusJakartaSans',
      appBarTheme: const AppBarTheme(
        backgroundColor: MekaarColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: MekaarColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: MekaarColors.surface,
        selectedItemColor: MekaarColors.textPrimary,
        unselectedItemColor: MekaarColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MekaarColors.surface2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: MekaarColors.sosAccent, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MekaarColors.textPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 32, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 28, fontWeight: FontWeight.w700),
        displaySmall: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 24, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 22, fontWeight: FontWeight.w600),
        headlineSmall: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(fontSize: 15, height: 1.6),
        bodyMedium: TextStyle(fontSize: 14, height: 1.5),
        bodySmall: TextStyle(fontSize: 12, color: MekaarColors.textMuted),
      ),
    );
  }
}
```

### 2.2 Common Widgets

**SOS Button (lib/core/widgets/sos_button.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:mekaar_app/core/constants/colors.dart';

class SOSButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isActive;
  final double size;
  
  const SOSButton({
    super.key,
    this.onPressed,
    this.isActive = false,
    this.size = 72,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: isActive ? size * 1.1 : size,
        height: isActive ? size * 1.1 : size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isActive ? MekaarColors.sosRed : MekaarColors.sosAccent,
          boxShadow: [
            BoxShadow(
              color: (isActive ? MekaarColors.sosRed : MekaarColors.sosAccent).withOpacity(0.4),
              blurRadius: 20,
              spreadRadius: isActive ? 8 : 4,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isActive)
              Positioned.fill(
                child: TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.8, end: 1.2),
                  duration: const Duration(seconds: 1),
                  builder: (context, value, child) {
                    return Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3 * (1 - (value - 0.8) / 0.4)),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: MekaarColors.sosRed.withOpacity(0.2 * (1 - (value - 0.8) / 0.4)),
                            blurRadius: 20 * value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const Text(
              'SOS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

**Avatar Widget (lib/core/widgets/avatar.dart):**

```dart
import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? initial;
  final String? imageUrl;
  final double size;
  final Color? backgroundColor;
  final bool isGuardian;
  
  const Avatar({
    super.key,
    this.initial,
    this.imageUrl,
    this.size = 48,
    this.backgroundColor,
    this.isGuardian = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor ?? _getDefaultColor(initial),
        image: imageUrl != null
            ? DecorationImage(image: NetworkImage(imageUrl!), fit: BoxFit.cover)
            : null,
        border: isGuardian
            ? Border.all(color: MekaarColors.guardian, width: 2)
            : null,
      ),
      child: imageUrl == null && initial != null
          ? Center(
              child: Text(
                initial.toUpperCase(),
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
    );
  }

  Color _getDefaultColor(String? text) {
    if (text == null) return const Color(0xFFE11D48);
    final colors = [
      const Color(0xFFE11D48),
      const Color(0xFF7C3AED),
      const Color(0xFF3B82F6),
      const Color(0xFF10B981),
      const Color(0xFFF59E0B),
    ];
    return colors[text.hashCode.abs() % colors.length];
  }
}
```

---

## 🔐 Phase 3: Authentication Implementation

### 3.1 Supabase Auth Integration

**Auth Provider (lib/features/auth/providers/auth_provider.dart):**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mekaar_app/core/supabase_client.dart';
import 'package:mekaar_app/data/models/user_model.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final Profile? profile;
  final bool isLoading;
  final String? error;

  AuthState({
    this.user,
    this.profile,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    User? user,
    Profile? profile,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      user: user ?? this.user,
      profile: profile ?? this.profile,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final session = SupabaseConfig.client.auth.currentSession;
    if (session != null) {
      state = state.copyWith(user: session.user);
      await loadProfile();
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      state = state.copyWith(user: response.user, isLoading: false);
      await loadProfile();
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUpWithEmail(String email, String password, String username) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await SupabaseConfig.client.auth.signUp(
        email: email,
        password: password,
      );
      if (response.user != null) {
        // Create profile
        await SupabaseConfig.client.from('profiles').insert({
          'id': response.user!.id,
          'username': username,
          'email': email,
        });
        state = state.copyWith(user: response.user, isLoading: false);
        await loadProfile();
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await SupabaseConfig.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'com.mekaar.app://auth-callback',
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadProfile() async {
    final user = state.user;
    if (user == null) return;

    try {
      final response = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();
      
      state = state.copyWith(
        profile: Profile.fromJson(response),
      );
    } catch (e) {
      // Profile might not exist yet
    }
  }

  Future<void> setPIN(String pin) async {
    final user = state.user;
    if (user == null) return;

    final pinHash = await _hashPIN(pin);
    await SupabaseConfig.client
        .from('profiles')
        .update({'pin_hash': pinHash})
        .eq('id', user.id);
  }

  Future<String> _hashPIN(String pin) async {
    // Use proper hashing (e.g., Argon2 or bcrypt)
    // For now, simple SHA-256
    final bytes = utf8.encode(pin);
    final hash = sha256.convert(bytes);
    return hash.toString();
  }

  Future<void> logout() async {
    await SupabaseConfig.client.auth.signOut();
    state = AuthState();
  }
}
```

### 3.2 PIN Screen Implementation

**PIN Screen (lib/features/auth/screens/pin_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/widgets/sos_button.dart';
import 'package:mekaar_app/features/auth/providers/auth_provider.dart';

class PinScreen extends ConsumerStatefulWidget {
  final bool isSetup;
  
  const PinScreen({super.key, this.isSetup = false});

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  String _pin = '';
  bool _isLocked = false;
  int _attempts = 0;
  
  static const int PIN_LENGTH = 6;
  static const int MAX_ATTEMPTS = 5;
  static const int LOCK_DURATION = 30; // minutes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Header
              Text(
                widget.isSetup ? 'Buat PIN' : 'Masukkan PIN',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.isSetup 
                    ? 'PIN 6 digit untuk membuka aplikasi'
                    : 'Masukkan PIN 6 digit untuk melanjutkan',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 40),
              
              // PIN Dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  PIN_LENGTH,
                  (index) => Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _pin.length > index 
                            ? MekaarColors.textPrimary 
                            : MekaarColors.border,
                        width: 2,
                      ),
                      color: _pin.length > index 
                          ? MekaarColors.textPrimary 
                          : Colors.transparent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
              
              // Keypad
              if (!_isLocked)
                Column(
                  children: [
                    _buildKeypadRow(['1', '2', '3']),
                    _buildKeypadRow(['4', '5', '6']),
                    _buildKeypadRow(['7', '8', '9']),
                    _buildKeypadRow(['', '0', '⌫']),
                  ],
                )
              else
                Column(
                  children: [
                    const Icon(Icons.lock_outline, size: 48, color: MekaarColors.sosRed),
                    const SizedBox(height: 16),
                    Text(
                      'Aplikasi terkunci selama $LOCK_DURATION menit',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tombol SOS tetap dapat diakses',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              
              const Spacer(),
              
              // SOS Button at bottom
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SOSButton(
                  onPressed: () {
                    // Trigger SOS even when locked
                    _triggerSOS();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 60);
        }
        return _buildKeyButton(key);
      }).toList(),
    );
  }

  Widget _buildKeyButton(String key) {
    final isBackspace = key == '⌫';
    final isSOS = key == 'SOS';
    
    return GestureDetector(
      onTap: () => _handleKeyPress(key),
      child: Container(
        width: 60,
        height: 60,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSOS 
              ? MekaarColors.sosAccent 
              : isBackspace 
                  ? Colors.transparent 
                  : MekaarColors.surface2,
        ),
        child: Center(
          child: isBackspace
              ? const Icon(Icons.backspace_outlined, color: MekaarColors.textMuted)
              : Text(
                  key,
                  style: TextStyle(
                    fontSize: isSOS ? 12 : 22,
                    fontWeight: FontWeight.w600,
                    color: isSOS ? Colors.white : MekaarColors.textPrimary,
                    letterSpacing: isSOS ? 0.5 : 0,
                  ),
                ),
        ),
      ),
    );
  }

  void _handleKeyPress(String key) {
    if (_isLocked) return;
    
    if (key == '⌫') {
      if (_pin.isNotEmpty) {
        setState(() => _pin = _pin.substring(0, _pin.length - 1));
      }
      return;
    }
    
    if (key == 'SOS') {
      _triggerSOS();
      return;
    }
    
    if (_pin.length < PIN_LENGTH) {
      setState(() => _pin += key);
      if (_pin.length == PIN_LENGTH) {
        _validatePIN();
      }
    }
  }

  void _validatePIN() async {
    // Check PIN against stored hash
    final isValid = await ref.read(authProvider.notifier).validatePIN(_pin);
    
    if (isValid) {
      // Navigate to home
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      _attempts++;
      if (_attempts >= MAX_ATTEMPTS) {
        setState(() {
          _isLocked = true;
          _pin = '';
        });
        // Auto-unlock after 30 minutes
        Future.delayed(const Duration(minutes: LOCK_DURATION), () {
          setState(() {
            _isLocked = false;
            _attempts = 0;
          });
        });
      } else {
        setState(() => _pin = '');
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PIN salah. ${MAX_ATTEMPTS - _attempts} percobaan tersisa'),
            backgroundColor: MekaarColors.sosRed,
          ),
        );
      }
    }
  }

  void _triggerSOS() {
    // Navigate to SOS overlay
    Navigator.pushNamed(context, '/sos/active');
  }
}
```

---

## 💬 Phase 4: Chat Implementation

### 4.1 Chat List Screen

**Chat List (lib/features/chat/screens/chat_list_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/widgets/sos_button.dart';
import 'package:mekaar_app/features/chat/widgets/chat_item.dart';

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  String _searchQuery = '';
  String _selectedTab = 'All';
  
  final List<String> _tabs = ['All', 'Guardian', 'Groups'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Text(
                    'Messages',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _showSearch(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.pushNamed(context, '/settings'),
                  ),
                ],
              ),
            ),
            
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (value) => setState(() => _searchQuery = value),
                decoration: InputDecoration(
                  hintText: 'Cari chat atau kontak...',
                  prefixIcon: const Icon(Icons.search, color: MekaarColors.textMuted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: MekaarColors.surface2,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Tabs
            SizedBox(
              height: 40,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                itemBuilder: (context, index) {
                  final tab = _tabs[index];
                  final isActive = _selectedTab == tab;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTab = tab),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: isActive ? MekaarColors.textPrimary : Colors.transparent,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        tab,
                        style: TextStyle(
                          color: isActive ? Colors.white : MekaarColors.textMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            
            // Chat list
            Expanded(
              child: _buildChatList(),
            ),
          ],
        ),
      ),
      floatingActionButton: const SOSButton(
        onPressed: _triggerSOS,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildChatList() {
    // This would be populated from the chat repository
    final chats = _getFilteredChats();
    
    if (chats.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 64, color: MekaarColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Belum Ada Chat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Mulai percakapan dengan kontak atau tambahkan guardian',
              style: TextStyle(color: MekaarColors.textMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: chats.length,
      itemBuilder: (context, index) {
        return ChatItem(chat: chats[index]);
      },
    );
  }

  List<ChatPreview> _getFilteredChats() {
    // Mock data for demonstration
    return [
      ChatPreview(
        id: '1',
        name: 'Budi Santoso',
        avatar: 'B',
        lastMessage: 'Lokasi terakhir: Jl. Sudirman',
        timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
        unreadCount: 2,
        isGuardian: true,
        isSOSActive: true,
      ),
      ChatPreview(
        id: '2',
        name: 'Siti Aminah',
        avatar: 'S',
        lastMessage: 'Oke, sampai ketemu besok ya!',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isGuardian: false,
        isSOSActive: false,
      ),
      ChatPreview(
        id: '3',
        name: 'Rina Wijaya',
        avatar: 'R',
        lastMessage: 'Izin kedaluwarsa dalam 5 hari',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        unreadCount: 0,
        isGuardian: true,
        isSOSActive: false,
      ),
    ].where((chat) {
      if (_searchQuery.isEmpty) return true;
      return chat.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).where((chat) {
      if (_selectedTab == 'All') return true;
      if (_selectedTab == 'Guardian') return chat.isGuardian;
      return !chat.isGuardian;
    }).toList();
  }

  void _showSearch() {
    // Navigate to search
  }

  void _triggerSOS() {
    Navigator.pushNamed(context, '/sos/active');
  }
}

class ChatPreview {
  final String id;
  final String name;
  final String avatar;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isGuardian;
  final bool isSOSActive;

  ChatPreview({
    required this.id,
    required this.name,
    required this.avatar,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isGuardian = false,
    this.isSOSActive = false,
  });
}
```

### 4.2 Chat Screen

**Chat Screen (lib/features/chat/screens/chat_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/widgets/avatar.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/features/chat/widgets/message_bubble.dart';
import 'package:mekaar_app/features/chat/widgets/message_input.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;
  final String chatName;
  final String chatAvatar;
  final bool isGuardian;
  
  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatAvatar,
    this.isGuardian = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  bool _isTyping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Avatar(
              initial: widget.chatAvatar,
              size: 36,
              isGuardian: widget.isGuardian,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chatName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: MekaarColors.success,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Online',
                        style: TextStyle(fontSize: 12, color: MekaarColors.success),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (widget.isGuardian) ...[
            IconButton(
              icon: const Icon(Icons.phone, color: MekaarColors.sosAccent),
              onPressed: () => _startCall(),
            ),
            IconButton(
              icon: const Icon(Icons.videocam, color: MekaarColors.sosAccent),
              onPressed: () => _startVideoCall(),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildMessages(),
          ),
          _buildTypingIndicator(),
          MessageInput(
            controller: _messageController,
            onSend: _sendMessage,
            onTyping: _onTyping,
          ),
        ],
      ),
    );
  }

  Widget _buildMessages() {
    // Would be populated from chat repository
    final messages = _getMockMessages();
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return MessageBubble(
          message: message,
          isSent: message.senderId == 'me',
        );
      },
    );
  }

  Widget _buildTypingIndicator() {
    if (!_isTyping) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Avatar(initial: 'B', size: 24),
          const SizedBox(width: 8),
          const Text(
            'mengetik...',
            style: TextStyle(fontSize: 12, color: MekaarColors.textMuted),
          ),
          const Spacer(),
          _buildTypingDots(),
        ],
      ),
    );
  }

  Widget _buildTypingDots() {
    return SizedBox(
      width: 40,
      height: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: MekaarColors.textMuted,
            ),
          );
        }),
      ),
    );
  }

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;
    
    // Add message to chat
    // This would be handled by the chat repository
    
    _messageController.clear();
    _scrollToBottom();
  }

  void _onTyping(String text) {
    // Send typing indicator via WebSocket/Realtime
    setState(() {
      _isTyping = text.isNotEmpty;
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _startCall() {
    // Implement voice call
  }

  void _startVideoCall() {
    // Implement video call
  }

  List<Message> _getMockMessages() {
    return [
      Message(
        id: '1',
        senderId: 'other',
        content: 'Hai, kamu sudah sampai kantor?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        type: MessageType.text,
      ),
      Message(
        id: '2',
        senderId: 'me',
        content: 'Sudah nih, baru aja sampai. Kenapa?',
        timestamp: DateTime.now().subtract(const Duration(minutes: 8)),
        type: MessageType.text,
      ),
      Message(
        id: '3',
        senderId: 'other',
        content: 'Aman-aman, cuma nanyain aja. Hati-hati di jalan ya!',
        timestamp: DateTime.now().subtract(const Duration(minutes: 7)),
        type: MessageType.text,
      ),
      if (widget.isGuardian)
        Message(
          id: '4',
          senderId: 'system',
          content: '🚨 SOS diaktifkan — Lokasi terkirim',
          timestamp: DateTime.now().subtract(const Duration(minutes: 6)),
          type: MessageType.system,
        ),
    ];
  }
}
```

### 4.3 Message Bubble Widget

**Message Bubble (lib/features/chat/widgets/message_bubble.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mekaar_app/core/constants/colors.dart';

enum MessageType { text, image, voice, video, system, location }

class Message {
  final String id;
  final String senderId;
  final String content;
  final DateTime timestamp;
  final MessageType type;
  final String? mediaUrl;
  final bool isViewOnce;
  final bool isDeleted;
  final String? replyToId;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.timestamp,
    required this.type,
    this.mediaUrl,
    this.isViewOnce = false,
    this.isDeleted = false,
    this.replyToId,
  });
}

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isSent;
  final bool showTimestamp;
  
  const MessageBubble({
    super.key,
    required this.message,
    required this.isSent,
    this.showTimestamp = true,
  });

  @override
  Widget build(BuildContext context) {
    if (message.type == MessageType.system) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: MekaarColors.sosLight,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          message.content,
          style: const TextStyle(
            color: MekaarColors.sosAccent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: isSent ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSent ? MekaarColors.textPrimary : MekaarColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isSent ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isSent ? const Radius.circular(4) : const Radius.circular(16),
                ),
                boxShadow: isSent ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.replyToId != null)
                    _buildReplyPreview(context),
                  _buildMessageContent(context),
                  if (showTimestamp)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm').format(message.timestamp),
                            style: TextStyle(
                              fontSize: 10,
                              color: isSent 
                                  ? Colors.white.withOpacity(0.6)
                                  : MekaarColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.isDeleted) {
      return Text(
        'Pesan telah dihapus',
        style: TextStyle(
          fontStyle: FontStyle.italic,
          color: isSent ? Colors.white.withOpacity(0.6) : MekaarColors.textMuted,
        ),
      );
    }

    switch (message.type) {
      case MessageType.text:
        return Text(
          message.content,
          style: TextStyle(
            color: isSent ? Colors.white : MekaarColors.textPrimary,
          ),
        );
      
      case MessageType.image:
        return _buildImageMessage(context);
      
      case MessageType.voice:
        return _buildVoiceMessage(context);
      
      case MessageType.location:
        return _buildLocationMessage(context);
      
      case MessageType.video:
        return _buildVideoMessage(context);
      
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildImageMessage(BuildContext context) {
    // Image preview with view-once handling
    return GestureDetector(
      onTap: () {
        // Show full-screen image
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 200,
          width: MediaQuery.of(context).size.width * 0.6,
          decoration: BoxDecoration(
            color: MekaarColors.surface2,
            image: DecorationImage(
              image: NetworkImage(message.mediaUrl!),
              fit: BoxFit.cover,
            ),
          ),
          child: message.isViewOnce
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.4),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.visibility_off,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildVoiceMessage(BuildContext context) {
    return SizedBox(
      width: 200,
      child: Row(
        children: [
          Icon(
            Icons.play_arrow,
            color: isSent ? Colors.white : MekaarColors.textPrimary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 4,
              decoration: BoxDecoration(
                color: isSent 
                    ? Colors.white.withOpacity(0.2)
                    : MekaarColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
              child: Container(
                width: 100,
                height: 4,
                decoration: BoxDecoration(
                  color: isSent ? Colors.white : MekaarColors.sosAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '0:42',
            style: TextStyle(
              fontSize: 12,
              color: isSent 
                  ? Colors.white.withOpacity(0.6)
                  : MekaarColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationMessage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Open map with location
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSent 
              ? Colors.white.withOpacity(0.1)
              : MekaarColors.surface2,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.location_on,
              color: MekaarColors.sosAccent,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message.content,
                style: TextStyle(
                  fontSize: 12,
                  color: isSent ? Colors.white : MekaarColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoMessage(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Play video
      },
      child: Container(
        height: 150,
        width: MediaQuery.of(context).size.width * 0.6,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
          image: message.mediaUrl != null
              ? DecorationImage(
                  image: NetworkImage(message.mediaUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: const Center(
          child: Icon(
            Icons.play_circle_filled,
            color: Colors.white,
            size: 48,
          ),
        ),
      ),
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSent 
            ? Colors.white.withOpacity(0.08)
            : MekaarColors.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isSent ? Colors.white.withOpacity(0.3) : MekaarColors.sosAccent,
            width: 2,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reply to...',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSent 
                        ? Colors.white.withOpacity(0.6)
                        : MekaarColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 12,
                    color: isSent ? Colors.white : MekaarColors.textPrimary,
                    overflow: TextOverflow.ellipsis,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 🚨 Phase 5: SOS & Emergency Features

### 5.1 SOS Active Screen

**SOS Active Screen (lib/features/sos/screens/sos_active_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/core/widgets/sos_button.dart';
import 'package:mekaar_app/features/sos/providers/sos_provider.dart';

class SOSActiveScreen extends ConsumerStatefulWidget {
  const SOSActiveScreen({super.key});

  @override
  ConsumerState<SOSActiveScreen> createState() => _SOSActiveScreenState();
}

class _SOSActiveScreenState extends ConsumerState<SOSActiveScreen> {
  int _elapsedSeconds = 0;
  bool _isVideoStreaming = false;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
    _triggerSOS();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _elapsedSeconds++);
        return true;
      }
      return false;
    });
  }

  Future<void> _triggerSOS() async {
    // Activate SOS on Supabase
    await ref.read(sosProvider.notifier).activateSOS();
  }

  @override
  Widget build(BuildContext context) {
    final sosState = ref.watch(sosProvider);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0A),
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                MekaarColors.sosRed.withOpacity(0.2),
                Colors.transparent,
              ],
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // SOS Icon with pulse
                _buildSOSIcon(),
                const SizedBox(height: 24),
                
                Text(
                  'MODE DARURAT AKTIF',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Guardian telah diberitahu. Lokasi GPS sedang dikirim secara real-time.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                
                // Timer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _formatDuration(Duration(seconds: _elapsedSeconds)),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          color: Colors.white,
                          fontFamily: 'SpaceGrotesk',
                        ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Streaming audio aktif',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Actions
                Column(
                  children: [
                    // Video button
                    ElevatedButton.icon(
                      onPressed: _toggleVideo,
                      icon: Icon(_isVideoStreaming ? Icons.stop : Icons.videocam),
                      label: Text(_isVideoStreaming ? 'Hentikan Video' : 'Kirim Video ke Guardian'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: MekaarColors.sosRed,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // End SOS button
                    OutlinedButton.icon(
                      onPressed: _endSOS,
                      icon: const Icon(Icons.close),
                      label: const Text('Akhiri Mode Darurat'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withOpacity(0.3)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSOSIcon() {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1.0, end: 1.1),
      duration: const Duration(seconds: 1),
      builder: (context, value, child) {
        return Container(
          width: 100 * value,
          height: 100 * value,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: MekaarColors.sosRed.withOpacity(0.2 * (value / 1.1)),
          ),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: MekaarColors.sosRed,
              ),
              child: const Center(
                child: Text(
                  'SOS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggleVideo() {
    setState(() => _isVideoStreaming = !_isVideoStreaming);
    if (_isVideoStreaming) {
      // Navigate to video streaming screen
      Navigator.pushNamed(context, '/sos/video');
    }
  }

  void _endSOS() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Akhiri Mode Darurat?'),
        content: const Text('Guardian akan berhenti menerima lokasi dan audio Anda.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () async {
              await ref.read(sosProvider.notifier).endSOS();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: MekaarColors.sosRed),
            child: const Text('Akhiri'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

### 5.2 Video Emergency Screen

**Video Emergency Screen (lib/features/sos/screens/video_emergency_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:mekaar_app/core/constants/colors.dart';

class VideoEmergencyScreen extends StatefulWidget {
  const VideoEmergencyScreen({super.key});

  @override
  State<VideoEmergencyScreen> createState() => _VideoEmergencyScreenState();
}

class _VideoEmergencyScreenState extends State<VideoEmergencyScreen> {
  bool _isFrontCamera = true;
  bool _isScreenLocked = false;
  int _recordingSeconds = 0;
  
  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) {
        setState(() => _recordingSeconds++);
        return true;
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview area
          Container(
            width: double.infinity,
            height: double.infinity,
            color: const Color(0xFF1A1A2E),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      _isFrontCamera ? Icons.person_outline : Icons.camera_alt_outlined,
                      size: 48,
                      color: Colors.white.withOpacity(0.2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Kamera ${_isFrontCamera ? 'Depan' : 'Belakang'} Aktif',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Recording indicator
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MekaarColors.sosRed,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'REC',
                    style: TextStyle(
                      color: MekaarColors.sosRed,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Timer
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatDuration(Duration(seconds: _recordingSeconds)),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'SpaceGrotesk',
                ),
              ),
            ),
          ),
          
          // Controls at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Switch camera
                      _buildControlButton(
                        icon: Icons.flip_camera_ios,
                        label: 'Ganti Kamera',
                        onTap: _switchCamera,
                      ),
                      
                      // Lock screen
                      _buildControlButton(
                        icon: _isScreenLocked ? Icons.lock : Icons.lock_open,
                        label: _isScreenLocked ? 'Terkunci' : 'Kunci Layar',
                        onTap: _toggleScreenLock,
                      ),
                      
                      // Stop button
                      _buildControlButton(
                        icon: Icons.stop_circle,
                        label: 'Hentikan',
                        onTap: _stopRecording,
                        isStop: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Streaming ke Budi Santoso · Tidak disimpan',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Status bar (OS indicators)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.circle, color: Colors.green, size: 10),
                        SizedBox(width: 6),
                        Text(
                          'Kamera Aktif',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isStop = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isStop 
                  ? MekaarColors.sosRed 
                  : Colors.white.withOpacity(0.1),
            ),
            child: Icon(
              icon,
              color: isStop ? Colors.white : Colors.white.withOpacity(0.8),
              size: isStop ? 36 : 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  void _switchCamera() {
    setState(() => _isFrontCamera = !_isFrontCamera);
    // Switch camera in WebRTC
  }

  void _toggleScreenLock() {
    setState(() => _isScreenLocked = !_isScreenLocked);
    // Lock screen (keep streaming alive)
    if (_isScreenLocked) {
      // Show persistent notification
    }
  }

  void _stopRecording() {
    Navigator.pop(context);
    // Show confirmation
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
```

---

## 📍 Phase 6: Location & Maps

### 6.1 Location Service

**Location Service (lib/data/services/location_service.dart):**

```dart
import 'package:location/location.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:mekaar_app/core/supabase_client.dart';

class LocationService {
  static final Location _location = Location();
  
  static Future<bool> requestPermission() async {
    final status = await Permission.location.request();
    return status.isGranted;
  }

  static Future<LocationData?> getCurrentLocation() async {
    final hasPermission = await requestPermission();
    if (!hasPermission) return null;
    
    try {
      return await _location.getLocation();
    } catch (e) {
      return null;
    }
  }

  static Stream<LocationData> getLocationStream() {
    return _location.onLocationChanged;
  }

  static Future<void> updateLocation(String sessionId, LocationData location) async {
    await SupabaseConfig.client.from('location_pings').insert({
      'session_id': sessionId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'accuracy': location.accuracy,
    });
  }

  static String getOpenStreetMapUrl(double lat, double lon) {
    return 'https://www.openstreetmap.org/?mlat=$lat&mlon=$lon#map=17/$lat/$lon';
  }

  static String getOpenStreetMapStaticUrl(double lat, double lon) {
    return 'https://tile.openstreetmap.org/17/${_tileX(lat, lon)}/${_tileY(lat, lon)}.png';
  }

  static int _tileX(double lat, double lon) {
    // Convert lat/lon to tile coordinates
    return ((lon + 180) / 360 * (1 << 17)).floor();
  }

  static int _tileY(double lat, double lon) {
    final latRad = lat * 3.141592653589793 / 180;
    return ((1 - (log(tan(latRad) + 1 / cos(latRad)) / 3.141592653589793)) / 2 * (1 << 17)).floor();
  }
}
```

### 6.2 Map Screen

**Location Map Screen (lib/features/map/screens/location_map_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mekaar_app/core/constants/colors.dart';

class LocationMapScreen extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String? locationName;
  
  const LocationMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.locationName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lokasi'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: LatLng(latitude, longitude),
                zoom: 17,
                maxZoom: 20,
                minZoom: 5,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.mekaar.app',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(latitude, longitude),
                      width: 60,
                      height: 60,
                      child: const Icon(
                        Icons.location_on,
                        color: MekaarColors.sosRed,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: MekaarColors.sosRed,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        locationName ?? 'Lokasi Anda',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Open in navigation app
                        },
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: MekaarColors.textPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Copy coordinates
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Salin'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## 📱 Phase 7: Guardian Management

### 7.1 Guardian List Screen

**Guardian List Screen (lib/features/guardian/screens/guardian_list_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/core/widgets/avatar.dart';
import 'package:mekaar_app/features/guardian/providers/guardian_provider.dart';

class GuardianListScreen extends ConsumerStatefulWidget {
  const GuardianListScreen({super.key});

  @override
  ConsumerState<GuardianListScreen> createState() => _GuardianListScreenState();
}

class _GuardianListScreenState extends ConsumerState<GuardianListScreen> {
  @override
  Widget build(BuildContext context) {
    final guardians = ref.watch(guardianProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Saya'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kelola orang terpercaya yang bisa membantu saat darurat',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            
            // Add button
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, '/guardian/add'),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: MekaarColors.border, width: 2, style: BorderStyle.solid),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.transparent,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, color: MekaarColors.textMuted),
                    const SizedBox(width: 8),
                    Text(
                      'Tambah Guardian',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: MekaarColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            Expanded(
              child: ListView.builder(
                itemCount: guardians.length,
                itemBuilder: (context, index) {
                  return _GuardianCard(guardian: guardians[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianCard extends StatelessWidget {
  final Guardian guardian;
  
  const _GuardianCard({required this.guardian});

  @override
  Widget build(BuildContext context) {
    final isExpired = guardian.expiresAt?.isBefore(DateTime.now()) ?? false;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Avatar(
            initial: guardian.name[0],
            size: 48,
            isGuardian: true,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        guardian.name,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MekaarColors.sosLight,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: const Text(
                          'Kedaluwarsa',
                          style: TextStyle(
                            fontSize: 10,
                            color: MekaarColors.sosAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  guardian.email,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildPermissionChip('GPS', guardian.permissions['gps'] ?? false),
                    const SizedBox(width: 6),
                    _buildPermissionChip('Mikrofon', guardian.permissions['mic'] ?? false),
                    const SizedBox(width: 6),
                    if (!isExpired)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: MekaarColors.successLight,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${guardian.daysRemaining} hari tersisa',
                          style: const TextStyle(
                            fontSize: 10,
                            color: MekaarColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () => _showGuardianOptions(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionChip(String label, bool isEnabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isEnabled ? MekaarColors.successLight : MekaarColors.sosLight,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isEnabled ? Icons.check_circle : Icons.cancel,
            size: 12,
            color: isEnabled ? MekaarColors.success : MekaarColors.sosAccent,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isEnabled ? MekaarColors.success : MekaarColors.sosAccent,
            ),
          ),
        ],
      ),
    );
  }

  void _showGuardianOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOptionTile(
                icon: Icons.shuffle,
                label: 'Tukar Posisi',
                onTap: () => Navigator.pop(context),
              ),
              _buildOptionTile(
                icon: Icons.refresh,
                label: 'Perbarui Izin',
                onTap: () => Navigator.pop(context),
              ),
              _buildOptionTile(
                icon: Icons.delete_outline,
                label: 'Hapus Guardian',
                onTap: () => Navigator.pop(context),
                isDestructive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? MekaarColors.sosRed : null),
      title: Text(label, style: TextStyle(color: isDestructive ? MekaarColors.sosRed : null)),
      onTap: onTap,
    );
  }
}
```

---

## 🔒 Phase 8: Security Logs

### 8.1 Security Logs Screen

**Security Logs (lib/features/settings/screens/security_logs_screen.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/data/models/security_log_model.dart';
import 'package:mekaar_app/features/settings/providers/log_provider.dart';

class SecurityLogsScreen extends ConsumerStatefulWidget {
  const SecurityLogsScreen({super.key});

  @override
  ConsumerState<SecurityLogsScreen> createState() => _SecurityLogsScreenState();
}

class _SecurityLogsScreenState extends ConsumerState<SecurityLogsScreen> {
  @override
  Widget build(BuildContext context) {
    final logs = ref.watch(securityLogProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Sistem'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            onPressed: _exportLogs,
          ),
        ],
      ),
      body: logs.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: MekaarColors.textMuted),
                  SizedBox(height: 16),
                  Text(
                    'Belum ada log',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Aktivitas keamanan akan tercatat di sini',
                    style: TextStyle(color: MekaarColors.textMuted),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return _LogItem(log: log);
              },
            ),
    );
  }

  void _exportLogs() {
    // Export to CSV/PDF
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ekspor Log'),
        content: const Text('Log akan diekspor sebagai file CSV.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () {
              // Trigger export
              Navigator.pop(context);
            },
            child: const Text('Ekspor'),
          ),
        ],
      ),
    );
  }
}

class _LogItem extends StatelessWidget {
  final SecurityLog log;
  
  const _LogItem({required this.log});

  @override
  Widget build(BuildContext context) {
    final iconData = _getIconForEvent(log.eventType);
    final color = _getColorForEvent(log.eventType);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: MekaarColors.borderLight, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(iconData, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getTitleForEvent(log.eventType),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  log.details?['description'] ?? '',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            DateFormat('HH:mm\ndd MMM').format(log.createdAt),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }

  IconData _getIconForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return Icons.warning_amber;
      case 'sos_ended':
        return Icons.check_circle;
      case 'guardian_gps_access':
        return Icons.location_on;
      case 'guardian_mic_access':
        return Icons.mic;
      case 'video_sent':
        return Icons.videocam;
      case 'message_deleted':
        return Icons.delete_outline;
      case 'log_deleted':
        return Icons.history_off;
      default:
        return Icons.info_outline;
    }
  }

  Color _getColorForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return MekaarColors.sosRed;
      case 'sos_ended':
        return MekaarColors.success;
      case 'guardian_gps_access':
        return MekaarColors.info;
      case 'guardian_mic_access':
        return MekaarColors.guardian;
      case 'video_sent':
        return MekaarColors.warning;
      case 'message_deleted':
        return MekaarColors.textMuted;
      case 'log_deleted':
        return MekaarColors.textMuted;
      default:
        return MekaarColors.textMuted;
    }
  }

  String _getTitleForEvent(String eventType) {
    switch (eventType) {
      case 'sos_started':
        return 'SOS Diaktifkan';
      case 'sos_ended':
        return 'SOS Diakhiri';
      case 'guardian_gps_access':
        return 'Guardian mengakses lokasi';
      case 'guardian_mic_access':
        return 'Guardian mengakses mikrofon';
      case 'video_sent':
        return 'Video darurat dikirim';
      case 'message_deleted':
        return 'Pesan dihapus';
      case 'log_deleted':
        return 'Log dihapus';
      default:
        return eventType.replaceAll('_', ' ').toUpperCase();
    }
  }
}
```

---

## 🚀 Phase 9: Push Notifications

### 9.1 Notification Service

**Notification Service (lib/data/services/notification_service.dart):**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/core/supabase_client.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications = 
      FlutterLocalNotificationsPlugin();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    // Initialize local notifications
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _localNotifications.initialize(settings);

    // Request permissions
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Get token
    final token = await _firebaseMessaging.getToken();
    if (token != null) {
      // Save token to Supabase
      await _saveToken(token);
    }

    // Listen to messages
    FirebaseMessaging.onMessage.listen(_handleMessage);
    FirebaseMessaging.onBackgroundMessage(_handleBackgroundMessage);
  }

  static Future<void> _saveToken(String token) async {
    final user = SupabaseConfig.client.auth.currentUser;
    if (user == null) return;

    await SupabaseConfig.client.from('push_tokens').upsert({
      'user_id': user.id,
      'token': token,
      'device': 'mobile',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static void _handleMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _showLocalNotification(
        title: notification.title ?? 'Mekaar',
        body: notification.body ?? '',
        data: message.data,
      );
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Handle background message
  }

  static Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'mekaar_channel',
      'Mekaar Notifications',
      channelDescription: 'Notifications from Mekaar',
      importance: Importance.max,
      priority: Priority.high,
      color: MekaarColors.sosRed,
      colorized: true,
      sound: RawResourceAndroidNotificationSound('sos_alarm'),
      enableVibration: true,
      vibrationPattern: [0, 500, 250, 500],
      visibility: NotificationVisibility.public,
      category: 'alarm',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      sound: 'sos_alarm.caf',
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: data != null ? data.toString() : null,
    );
  }

  static Future<void> sendSOSNotification({
    required String guardianId,
    required String userName,
    required double latitude,
    required double longitude,
  }) async {
    // This would trigger a push notification via Supabase Edge Function
    await SupabaseConfig.client.functions.invoke(
      'send-sos-notification',
      body: {
        'guardian_id': guardianId,
        'user_name': userName,
        'latitude': latitude,
        'longitude': longitude,
        'map_url': 'https://www.openstreetmap.org/?mlat=$latitude&mlon=$longitude#map=17/$latitude/$longitude',
      },
    );
  }
}
```

---

## 🗺️ Phase 10: Navigation & Routing

### 10.1 App Routes

**App Routes (lib/core/routes/app_routes.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:mekaar_app/features/auth/screens/login_screen.dart';
import 'package:mekaar_app/features/auth/screens/onboarding_screen.dart';
import 'package:mekaar_app/features/auth/screens/pin_screen.dart';
import 'package:mekaar_app/features/auth/screens/splash_screen.dart';
import 'package:mekaar_app/features/chat/screens/chat_list_screen.dart';
import 'package:mekaar_app/features/chat/screens/chat_screen.dart';
import 'package:mekaar_app/features/guardian/screens/guardian_list_screen.dart';
import 'package:mekaar_app/features/guardian/screens/add_guardian_screen.dart';
import 'package:mekaar_app/features/settings/screens/settings_screen.dart';
import 'package:mekaar_app/features/settings/screens/security_logs_screen.dart';
import 'package:mekaar_app/features/settings/screens/profile_screen.dart';
import 'package:mekaar_app/features/sos/screens/sos_active_screen.dart';
import 'package:mekaar_app/features/sos/screens/video_emergency_screen.dart';
import 'package:mekaar_app/features/sos/screens/device_lost_screen.dart';
import 'package:mekaar_app/features/map/screens/location_map_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String pin = '/pin';
  static const String home = '/home';
  static const String chat = '/chat';
  static const String guardian = '/guardian';
  static const String guardianAdd = '/guardian/add';
  static const String settings = '/settings';
  static const String logs = '/logs';
  static const String profile = '/profile';
  static const String sosActive = '/sos/active';
  static const String sosVideo = '/sos/video';
  static const String deviceLost = '/sos/lost';
  static const String map = '/map';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      
      case onboarding:
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      
      case pin:
        final isSetup = settings.arguments as bool? ?? false;
        return MaterialPageRoute(builder: (_) => PinScreen(isSetup: isSetup));
      
      case home:
        return MaterialPageRoute(builder: (_) => const ChatListScreen());
      
      case chat:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => ChatScreen(
            chatId: args['chatId'],
            chatName: args['chatName'],
            chatAvatar: args['chatAvatar'],
            isGuardian: args['isGuardian'] ?? false,
          ),
        );
      
      case guardian:
        return MaterialPageRoute(builder: (_) => const GuardianListScreen());
      
      case guardianAdd:
        return MaterialPageRoute(builder: (_) => const AddGuardianScreen());
      
      case settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      
      case logs:
        return MaterialPageRoute(builder: (_) => const SecurityLogsScreen());
      
      case profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case sosActive:
        return MaterialPageRoute(builder: (_) => const SOSActiveScreen());
      
      case sosVideo:
        return MaterialPageRoute(builder: (_) => const VideoEmergencyScreen());
      
      case deviceLost:
        return MaterialPageRoute(builder: (_) => const DeviceLostScreen());
      
      case map:
        final args = settings.arguments as Map<String, double>;
        return MaterialPageRoute(
          builder: (_) => LocationMapScreen(
            latitude: args['latitude']!,
            longitude: args['longitude']!,
            locationName: args['locationName'] as String?,
          ),
        );
      
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(child: Text('Route not found: ${settings.name}')),
          ),
        );
    }
  }
}
```

### 10.2 Main App

**Main App (lib/app.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekaar_app/core/routes/app_routes.dart';
import 'package:mekaar_app/core/constants/colors.dart';
import 'package:mekaar_app/core/supabase_client.dart';

class MekaarApp extends ConsumerWidget {
  const MekaarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'MEKAAR',
      theme: MekaarTheme.lightTheme(),
      darkTheme: MekaarTheme.darkTheme(),
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.splash,
      onGenerateRoute: AppRoutes.generateRoute,
    );
  }
}
```

**Main Entry (lib/main.dart):**

```dart
import 'package:flutter/material.dart';
import 'package:mekaar_app/app.dart';
import 'package:mekaar_app/core/supabase_client.dart';
import 'package:mekaar_app/data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  // Initialize notifications
  await NotificationService.initialize();
  
  runApp(const MekaarApp());
}
```

---

## 📋 Implementation Checklist

### Phase 1: Foundation (Week 1-2)
- [ ] Project setup with Flutter
- [ ] Supabase project creation
- [ ] Database schema migration
- [ ] RLS policies setup
- [ ] Design system (colors, typography, theme)
- [ ] Common widgets (Avatar, SOS Button, etc.)

### Phase 2: Authentication (Week 2-3)
- [ ] Email/password login
- [ ] Google OAuth
- [ ] Registration flow
- [ ] PIN creation and validation
- [ ] PIN lock screen (with SOS access)

### Phase 3: Chat Core (Week 3-5)
- [ ] Chat list screen
- [ ] Chat screen
- [ ] Message bubble with all types
- [ ] Message input with attachments
- [ ] Reply/Quote functionality
- [ ] Typing indicator
- [ ] View-Once media
- [ ] Read receipts (optional)
- [ ] Forward messages (with restrictions)

### Phase 4: SOS & Emergency (Week 5-7)
- [ ] SOS activation (all entry points)
- [ ] SOS active screen with timer
- [ ] GPS location streaming
- [ ] Audio streaming
- [ ] Video emergency streaming
- [ ] Inactivity auto-end
- [ ] Device lost mode (no mic/camera)
- [ ] Persistent notification

### Phase 5: Guardian Management (Week 6-8)
- [ ] Add guardian by email/username
- [ ] Guardian list with permissions
- [ ] Permission management (GPS, Mic)
- [ ] Storage options
- [ ] Switch guardian (two-way)
- [ ] Guardian expiration (30 days)
- [ ] Guardian chat restrictions

### Phase 6: Security & Data Management (Week 7-9)
- [ ] Security logs (permanent)
- [ ] Log export (CSV/PDF)
- [ ] 3-layer data management
- [ ] Chat auto-delete (with warnings)
- [ ] E2EE for all messages
- [ ] Message deletion tracking

### Phase 7: UI Polish (Week 9-10)
- [ ] Responsive layouts
- [ ] Animations (pulse, breathe)
- [ ] Haptic feedback
- [ ] Light/Dark mode
- [ ] Error handling
- [ ] Loading states
- [ ] Empty states

### Phase 8: Testing & Deployment (Week 10-12)
- [ ] Unit tests
- [ ] Widget tests
- [ ] Integration tests
- [ ] Security audit
- [ ] Play Store/App Store submission
- [ ] Documentation

---

## 🔧 Environment Variables

Create `.env` file:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_anon_key
GOOGLE_CLIENT_ID=your_google_client_id
FCM_SENDER_ID=your_fcm_sender_id
```

---

## 📊 Supabase Edge Functions

### SOS Notification Function

```typescript
// supabase/functions/send-sos-notification/index.ts
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { guardian_id, user_name, latitude, longitude, map_url } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get guardian's push token
    const { data: tokenData } = await supabase
      .from('push_tokens')
      .select('token')
      .eq('user_id', guardian_id)
      .single()

    if (!tokenData?.token) {
      throw new Error('Guardian has no push token')
    }

    // Send via FCM
    const response = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        to: tokenData.token,
        priority: 'high',
        notification: {
          title: '🚨 SOS Emergency!',
          body: `${user_name} is in danger! Location: ${latitude}, ${longitude}`,
          sound: 'default',
          android_channel_id: 'mekaar_sos',
        },
        data: {
          type: 'sos',
          user_id: user_name,
          latitude: latitude.toString(),
          longitude: longitude.toString(),
          map_url: map_url,
        },
      }),
    })

    return new Response(JSON.stringify({ success: true }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 400,
    })
  }
})
```

---

## 🎯 Final Notes

### Key Differentiators to Maintain

1. **Initiative from Within**: No guardian-initiated access. Only SOS trigger.
2. **3-Layer Data**: Chat normal, chat guardian (with restrictions), logs (permanent).
3. **No Edit in Guardian Chat**: Prevent altering evidence.
4. **No Send Without Notification**: Cannot bypass guardian notifications.
5. **OS Indicators Always Visible**: Cannot hide camera/mic indicators.
6. **Guardian Expiration**: 30-day auto-expiry to maintain active consent.

### Security Checklist

- [ ] All API calls use RLS policies
- [ ] All sensitive data encrypted in transit
- [ ] E2EE for messages and media
- [ ] PIN hashed with strong algorithm
- [ ] Biometric authentication optional
- [ ] Security logs permanent
- [ ] No remote sensor activation
- [ ] OS indicators never hidden

---

*This implementation guide provides a complete roadmap for building MEKAAR 3.0. Follow the phases sequentially for best results.*