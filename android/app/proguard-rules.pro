# R8 keep rules for release builds.
#
# shared_preferences_android 2.5.x uses Pigeon's JNI backend. The Dart side
# resolves these methods by name at runtime, so R8 must not rename or strip
# them. Without this, release builds crash during startup with
# NoSuchMethodError (SharedPreferencesApiRegistrar.getAll) and stay on the
# splash screen while debug builds work.
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# Keep first-party Flutter plugin entry points and their Pigeon members. This
# covers the camera, url_launcher and other io.flutter.plugins packages if a
# future upgrade moves them to Pigeon JNI as well.
-keep class io.flutter.plugins.** { *; }

# Pigeon's JNI backend builds method signatures and reads objects with the
# original Kotlin names and members:
#   (String, List, kotlin.coroutines.Continuation) -> Object
#   kotlin.Result.value, kotlin.Result$Failure.exception, kotlin.Unit.INSTANCE, ...
# R8 renaming or stripping any of these breaks the lookup at runtime, even
# when the plugin method itself is kept. These classes are small; keep them
# whole rather than relying on incidental references.
-keep class kotlin.Result { *; }
-keep class kotlin.Result$Failure { *; }
-keep class kotlin.Unit { *; }
-keep class kotlin.coroutines.Continuation { *; }
-keep class kotlin.coroutines.intrinsics.IntrinsicsKt { *; }
-keep class kotlin.coroutines.intrinsics.CoroutineSingletons { *; }
-keepnames class kotlin.coroutines.** { *; }

