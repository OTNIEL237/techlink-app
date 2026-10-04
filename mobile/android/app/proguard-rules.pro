# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Zego UIKit & Audio/Video Engine
-keep class **.zego.** { *; }
-keep class **.zegolibrary.** { *; }
-keep class **.zego_zpns.** { *; }
-keep class **.zego_zim.** { *; }
-keep class **.zego_uikit.** { *; }
-dontwarn **.zego.**

# Java 8+ Desugaring
-keep class j$.** { *; }
