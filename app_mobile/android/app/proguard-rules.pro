# Add project specific ProGuard rules here.

# === TensorFlow Lite Core ===
-keep class org.tensorflow.lite.** { *; }
-keep interface org.tensorflow.lite.** { *; }
-keepclassmembers class org.tensorflow.lite.** { *; }

# === TensorFlow Lite GPU (if exists) ===
-keep class org.tensorflow.lite.gpu.** { *; }
-keep interface org.tensorflow.lite.gpu.** { *; }

# === Prevent stripping native methods ===
-keepclasseswithmembernames class * {
    native <methods>;
}

# === Flutter TFLite Plugin ===
-keep class sq.flutter.** { *; }

# === Suppress warnings for optional dependencies ===
-dontwarn org.tensorflow.lite.gpu.**
-dontwarn com.google.android.gms.tflite.**
-dontwarn org.tensorflow.lite.task.**

# === Keep annotation for reflection ===
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions

# SnakeYAML
-dontwarn java.beans.**
-keep class org.yaml.snakeyaml.** { *; }

# Ultralytics YOLO
-keep class com.ultralytics.yolo.** { *; }