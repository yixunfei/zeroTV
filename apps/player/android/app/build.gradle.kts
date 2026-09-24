import java.io.File
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing: prefers android/key.properties (local builds, gitignored),
// falls back to ZEROTV_KEYSTORE_B64 env var (CI: base64 of the .jks keystore).
// Without either, release builds fall back to debug signing (dev only).
val keystoreProperties = Properties().apply {
    val keyPropertiesFile = rootProject.file("key.properties")
    if (keyPropertiesFile.exists()) {
        keyPropertiesFile.inputStream().use { load(it) }
    }
}
val envKeystoreB64: String? = System.getenv("ZEROTV_KEYSTORE_B64")
val hasSigningMaterial = keystoreProperties.isNotEmpty() || !envKeystoreB64.isNullOrEmpty()

android {
    namespace = "dev.zerotv.zerotv_player"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "dev.zerotv.zerotv_player"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystoreProperties.isNotEmpty()) {
                storeFile = rootProject.file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
            } else if (!envKeystoreB64.isNullOrEmpty()) {
                // CI path: materialize the keystore from base64 into build dir.
                val keystoreFile = File(layout.buildDirectory.asFile.get(), "release.keystore")
                keystoreFile.parentFile.mkdirs()
                keystoreFile.writeBytes(Base64.getDecoder().decode(envKeystoreB64))
                storeFile = keystoreFile
                storePassword = System.getenv("ZEROTV_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("ZEROTV_KEY_ALIAS")
                keyPassword = System.getenv("ZEROTV_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            // Uses the release signing config when keystore material is
            // available (key.properties locally / env vars in CI); otherwise
            // falls back to debug signing so `flutter run --release` still works.
            signingConfig = if (hasSigningMaterial) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
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
