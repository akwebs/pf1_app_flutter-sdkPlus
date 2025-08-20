# Keep ALPR SDK classes and methods
-keep class org.buyun.alpr.sdk.** { *; }
-keepclassmembers class org.buyun.alpr.sdk.** { *; }
-keepclassmembers class * implements org.buyun.alpr.sdk.AlprCallback { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep JNI methods
-keepclasseswithmembernames class * {
    native <methods>;
    public <init>(android.content.Context, ...);
}

# Keep Parcelable classes
-keepclassmembers class * implements android.os.Parcelable {
    static ** CREATOR;
}

# Keep R8 rules
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keepattributes Signature
-keepattributes Exceptions

# Keep your application class
-keep class com.akwebs.kota_parking.** { *; }

# Keep ALPR specific rules
-keep class org.buyun.alpr.sdk.alprjni { *; }
-keepclassmembers class org.buyun.alpr.sdk.alprjni { *; }
-keepclassmembers class org.buyun.alpr.sdk.AlprCallback { *; }

# Keep Flutter plugin classes
-keep class com.kbyai.alprsdk_plugin.** { *; }
-keepclassmembers class com.kbyai.alprsdk_plugin.** { *; }

# Keep Handler and Message classes
-keepclassmembers class * extends android.os.Handler {
    public void handleMessage(android.os.Message);
    public void dispatchMessage(android.os.Message);
}

# Keep WeakReference
-keep class java.lang.ref.WeakReference { *; }