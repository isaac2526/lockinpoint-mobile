# Flutter's own engine classes are reached from native code, so R8 cannot see
# the references and would strip them. The Flutter tool ships these rules for
# exactly this reason; they are repeated here because minification is enabled
# in this project's release build and the defaults do not cover them.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core is referenced by Flutter's deferred-component support even when
# this app uses none, and R8 warns about the missing classes.
-dontwarn com.google.android.play.core.**
