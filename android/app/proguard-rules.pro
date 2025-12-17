# Flutter-specific ProGuard rules

# Keep Flutter classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep model classes for Gson/JSON serialization (if used)
-keepattributes Signature
-keepattributes *Annotation*

# Prevent stripping of native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep enum classes
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Suppress warnings for missing Play Core library
-dontwarn com.google.android.play.core.**

