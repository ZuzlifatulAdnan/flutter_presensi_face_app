# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# Keep TensorFlow Lite classes
-keep class org.tensorflow.lite.** { *; }
-keep class org.tensorflow.lite.gpu.** { *; }
-keep interface org.tensorflow.lite.** { *; }

# Suppress warnings for TensorFlow Lite GPU
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Keep Google ML Kit classes
-keep class com.google.mlkit.** { *; }
-keep interface com.google.mlkit.** { *; }

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# Keep native methods
-keepclassmembers class * {
    native <methods>;
}

# --- Play Store release (R8 penuh) ---

# Flutter embedding & plugin registrant.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# flutter_local_notifications memakai Gson untuk menyimpan jadwal notifikasi.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn com.google.gson.**

# ML Kit mengunduh model lewat Play Services; kelasnya diakses via refleksi.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.mlkit.**

# TensorFlow Lite memuat delegate lewat refleksi.
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**
