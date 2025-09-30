plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android")          // ⬅ ใช้ id นี้ให้ตรงกับ settings.gradle
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.flutter_app_test"

    // จะใช้แบบนี้ก็ได้ ถ้า flutter.compileSdkVersion เป็น 34 อยู่แล้ว
    compileSdk = flutter.compileSdkVersion
    // หรือกำหนดตรงไปเลย:
    // compileSdk = 34

    ndkVersion = "27.0.12077973"

    compileOptions {
        // ใช้ Java 17 ให้สอดคล้องกับ AGP/Kotlin รุ่นใหม่
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.flutter_app_test"
        minSdk = flutter.minSdkVersion                // แนะนำ 23+
        targetSdk = 34             // ⬅ อัปเป็น 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            // ใส่ signingConfig ของ release เองภายหลังได้
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
