import java.io.FileInputStream
import java.util.Properties

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

   CI (play-aab.yml, release.yml) writes that file from the repository secrets
   before Gradle is invoked; a developer creates it once by hand.

   WHO IS ALLOWED TO BUILD WITHOUT IT
   ----------------------------------
   A DEBUG build is: anyone, always. `flutter run`, `flutter test`, a fresh
   clone, a contributor with no key material — all of these must work, because
   a project you cannot run is a project nobody can fix.

   A RELEASE build is: nobody, without the real key. This is the line that was
   crossed in Oct 2026 — a workflow with no key ran `flutter build appbundle
   --release`, Gradle quietly reached for the debug key, and the Play Console
   rejected the upload for carrying the wrong certificate.

   So the check below is REAL but SCOPED. It was briefly written as a
   top-level `require(...)`, which fires during configuration of every single
   Gradle invocation — that version did stop the bad bundle, and also stopped
   `flutter run`, every debug build and every test on any machine without the
   key. Reading the task names keeps the guarantee for release builds and
   gives everyone else their project back.
   ============================================================================ */
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) FileInputStream(f).use { load(it) }
}
val hasUploadKey = keystoreProperties.getProperty("storeFile") != null

// `flutter build appbundle --release` asks Gradle for :app:bundleRelease;
// `flutter build apk --release` asks for :app:assembleRelease. Both carry
// "Release". A debug or test invocation never does.
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release") }

if (isReleaseBuild && !hasUploadKey) {
    throw GradleException(
        "RELEASE BUILD WITHOUT THE PLAY UPLOAD KEY.\n" +
        "android/key.properties is missing, so this build would be signed with the " +
        "debug key and Google Play would reject the bundle for carrying the wrong " +
        "certificate.\n" +
        "Build Play artifacts with the play-aab or release workflow, which write " +
        "key.properties from the repository secrets. For a build to install on a " +
        "phone, use a debug build instead."
    )
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
        // Only declared when the key is actually here. A signingConfig that
        // points at a storeFile of null fails at configuration time, which
        // would take debug builds down with it.
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
            // When the key is here, it is used — always, no fallback.
            // When it is not, a release build has already been refused above,
            // so the only way to reach this line without a key is a debug
            // build, which never reads it.
            if (hasUploadKey) {
                signingConfig = signingConfigs.getByName("upload")
            }
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
