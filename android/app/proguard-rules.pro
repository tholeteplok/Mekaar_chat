# Flutter Wrapper & Engine
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# WebRTC
-keep class org.webrtc.** { *; }

# Mobile Scanner (MLKit)
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.** { *; }

# JNI & Rust Core FFI
-keep class com.sun.jna.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}
