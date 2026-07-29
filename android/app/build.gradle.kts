import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

fun signingSecret(name: String): String {
    val directValue = keystoreProperties.getProperty(name)?.trim()
    if (!directValue.isNullOrEmpty()) {
        return directValue
    }

    val secretFilePath = keystoreProperties.getProperty("${name}File")?.trim()
    if (secretFilePath.isNullOrEmpty()) {
        throw GradleException(
            "Missing $name or ${name}File in android/key.properties."
        )
    }
    val secretFile = rootProject.file(secretFilePath)
    if (!secretFile.isFile) {
        throw GradleException("Signing secret file does not exist: $secretFile")
    }
    return secretFile.readText().trim().ifEmpty {
        throw GradleException("Signing secret file is empty: $secretFile")
    }
}

android {
    namespace = "com.cw.wordsearch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.cw.wordsearch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 23
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobApplicationId"] = "ca-app-pub-3940256099942544~3347511713"
    }

    if (keystorePropertiesFile.exists()) {
        signingConfigs {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = signingSecret("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = signingSecret("storePassword")
            }
        }
    }

    buildTypes {
        debug {
            manifestPlaceholders["admobApplicationId"] = "ca-app-pub-3940256099942544~3347511713"
        }
        release {
            manifestPlaceholders["admobApplicationId"] = "ca-app-pub-4013657131703981~5892899586"
            if (keystorePropertiesFile.exists()) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

flutter {
    source = "../.."
}

gradle.taskGraph.whenReady {
    if (!keystorePropertiesFile.exists() && allTasks.any { it.name.contains("Release") }) {
        throw GradleException(
            "Missing android/key.properties. Configure the upload keystore before building release."
        )
    }
}
