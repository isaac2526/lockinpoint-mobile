import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/* ============================================================================
   THE UPLOAD KEY.

   android/key.properties is git-ignored and holds four lines:

       storeFile=/absolute/path/to/upload-keystore.jks
       storePassword=…
       keyAlias=upload
       keyPassword=…

   CI writes that file from repository secrets before building; a developer
   creates it once by hand. When it is absent — a fresh clone, a contributor,
   `flutter run --release` on a laptop — the build still works and signs with
   the debug key, because a release build that cannot be run locally is a
   release build nobody tests.

   Google Play REFUSES a debug-signed bundle, so the artifact tells you which
   it got rather than leaving you to find out at upload time.
   ============================================================================ */
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

android {
    namespace = "com.lockinpoint.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // The listing on Google Play is this id. It does not change, ever.
        applicationId = "com.lockinpoint.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKey) {
            create("upload") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // The real key when there is one, the debug key when there is not.
            // Never silently: the build prints which, so a debug-signed bundle
            // is discovered here rather than by the Play Console.
            signingConfig = if (hasUploadKey) {
                signingConfigs.getByName("upload")
            } else {
                logger.lifecycle("[lockinpoint] No android/key.properties — signing the release with the DEBUG key. Google Play will refuse this bundle.")
                signingConfigs.getByName("debug")
            }
            /* Shrink and obfuscate. A release carrying every unreachable
               class is a download a student pays for out of a data bundle,
               and the Flutter engine's own classes are reached from native
               code where R8 cannot see the references — hence the keep rules
               beside this file. */
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
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
