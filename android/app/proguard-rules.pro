# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Firebase / Firestore
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep all model classes (used for serialization)
-keep class com.example.replaced.model.** { *; }

# Keep all Parcelable and Serializable classes
-keepclassmembers class * implements android.os.Parcelable { *; }
-keepclassmembers class * implements java.io.Serializable { *; }

# Keep enum classes
-keepclassmembers enum * { *; }

# Keep R8 from stripping generic signatures
-keepattributes Signature
-keepattributes *Annotation*

# Keep Gson/JSON serialization
-keepclassmembers class * { @com.google.gson.annotations.SerializedName <fields>; }

# Play Core SplitCompat (optional, used by Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }
