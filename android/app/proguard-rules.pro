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

# Google Play Core & Deferred Components (Opsional pada Flutter Engine)
-dontwarn com.google.android.play.core.**
-dontwarn io.flutter.embedding.engine.deferredcomponents.**

# JNI & Rust Core FFI
-keep class com.sun.jna.** { *; }
-keepclasseswithmembernames class * {
    native <methods>;
}

# MEKAAR Native Receivers, Notification Managers & JNI Bridge
-keep class com.mekaar.mekaar_chat.** { *; }

# Firebase Cloud Messaging
-keep class com.google.firebase.messaging.** { *; }

# Flutter Local Notifications & Gson
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepclassmembers,allowobfuscation class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
