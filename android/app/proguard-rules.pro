# Prevent WorkManager from crashing during initialization by keeping its database classes
-keep class androidx.work.** { *; }
-dontwarn androidx.work.**
