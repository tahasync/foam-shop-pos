# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Firebase / Firestore
#
# There are deliberately NO blanket `-keep class com.google.firebase.**` or
# `-keep class com.google.android.gms.**` rules here. Both libraries ship their
# own consumer ProGuard rules, which is exactly why those rules exist; keeping
# the whole trees disabled R8's shrinking and obfuscation across the two largest
# dependency trees in the app. That inflated the APK and left every class and
# member name readable in a decompiled release build, which lowers the cost of
# reverse-engineering the app for anyone who obtains the APK.
#
# If R8 ever breaks something specific, add a TARGETED keep for that one class
# here and say why - do not restore a package-wide keep.
#
# Note: the business models (lib/models/*.dart) are pure Dart, compiled into the
# AOT snapshot, so no Java keep rule was ever needed to protect them. A rule
# reading `-keep class com.example.replaced.model.**` sat here for a while -
# `com.example.replaced` is the Flutter project-template namespace, and this
# app's is `com.asif.foamshop`, so it matched nothing and never has. It read as
# protection that did not exist, so it is gone.

# Keep R8 from stripping generic signatures
-keepattributes Signature
-keepattributes *Annotation*

# Play Core SplitCompat (optional, used by Flutter deferred components)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }
