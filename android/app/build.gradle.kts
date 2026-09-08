import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ---------------------------------------------------------------------------
// ONE SIGNATURE, FOR EVER.
//
// This file used to say `signingConfig = signingConfigs.getByName("debug")`
// under `release`, which is the Flutter template's own placeholder. The debug
// keystore is GENERATED FRESH on every CI runner, so no two release builds
// this repository ever produced shared a signature — and Android refuses to
// install an update signed by a different key. Every new build meant
// "uninstall the old one first", which throws away everything the student had
// downloaded. Play is stricter still: the first upload fixes the key for the
// life of the listing.
//
// The real key is read from android/key.properties, which CI writes after
// decrypting android-signing/lip-release.jks.enc. That file is never
// committed. If it is absent — a contributor building locally, or a fork with
// no secrets — the build falls back to debug and SAYS SO in the build log,
// because a silent fallback is exactly how this went unnoticed.
// ---------------------------------------------------------------------------
val keyProps = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keyProps.getProperty("storeFile") != null

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
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs,
        // 1000 * ABI_VERSION is added automatically by Flutter.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                // storeFile is written ABSOLUTE by CI on purpose: file()
                // inside android { } resolves a relative path against
                // android/app/, not android/, so a bare filename would look
                // in the wrong directory and fall back to debug in silence.
                storeFile = file(keyProps.getProperty("storeFile"))
                storePassword = keyProps.getProperty("storePassword")
                keyAlias = keyProps.getProperty("keyAlias")
                keyPassword = keyProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseKey) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                println("WARNING: android/key.properties is missing. This release " +
                        "build is signed with the DEBUG key. It installs, but it " +
                        "cannot update an existing install and Play will refuse it.")
                signingConfig = signingConfigs.getByName("debug")
            }
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
