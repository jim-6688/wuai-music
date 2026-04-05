# Flutter ProGuard Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Riverpod
-keep class * extends StateNotifier { *; }

# Audio Service
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audio_session.** { *; }

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }

# SMB Connect
-keep class com.jsturlen.smbconnect.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JSON serialization
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# Remove logging
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int i(...);
    public static int w(...);
    public static int d(...);
    public static int e(...);
}

# Remove debug code
-assumenosideeffects class kotlin.jvm.internal.Intrinsics {
    static void checkParameterIsNotNull(...);
    static void checkNotNullParameter(...);
}

# Play Core - don't warn about missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Additional optimization for size
-optimizationpasses 5
-dontusemixedcaseclassnames
-dontskipnonpubliclibraryclasses
-dontpreverify
-verbose
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*

# Remove unused resources
-dontwarn android.support.**
-dontwarn androidx.**
-keep class androidx.** { *; }
-keep interface androidx.** { *; }

# Compress APK further
-repackageclasses ''
-allowaccessmodification