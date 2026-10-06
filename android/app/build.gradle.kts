import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/* ============================================================================
   THE UPLOAD KEY.

   CI writes android/key.properties from the GitHub Actions secrets before
   Gradle is invoked. A release build must never silently fall back to the
   debug key: Google Play rejects that certificate and the resulting AAB is
   not a valid production artifact.
   ============================================================================ */
val keyPropertiesFile = rootProject.file("key.properties")
require(keyPropertiesFile.isFile) {
    "Missing android/key.properties; release builds require the Play upload key"
}

val keystoreProperties = Properties().apply {
    FileInputStream(keyPropertiesFile).use { load(it) }
}

val uploadStoreFile = requireNotNull(keystoreProperties.getProperty("storeFile")) {
    "android/key.properties is missing storeFile"
}
val uploadStorePassword = requireNotNull(keystoreProperties.getProperty("storePassword")) {
    "android/key.properties is missing storePassword"
}
val uploadKeyAlias = requireNotNull(keystoreProperties.getProperty("keyAlias")) {
    "android/key.properties is missing keyAlias"
}
val uploadKeyPassword = requireNotNull(keystoreProperties.getProperty("keyPassword")) {
    "android/key.properties is missing keyPassword"
}

android {
    namespace = "com.lockinpoint.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.lockinpoint.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 22
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("upload") {
            storeFile = file(uploadStoreFile)
            storePassword = uploadStorePassword
            keyAlias = uploadKeyAlias
            keyPassword = uploadKeyPassword
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("upload")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
