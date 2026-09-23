plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing is supplied by the developer or by a disposable CI key.
// Debug builds still work without these variables; release builds fail closed.
val uploadKeystorePath = System.getenv("GROOVEFOLIO_UPLOAD_KEYSTORE")
val uploadKeyAlias = System.getenv("GROOVEFOLIO_UPLOAD_KEY_ALIAS")
val uploadStorePassword = System.getenv("GROOVEFOLIO_UPLOAD_STORE_PASSWORD")
val uploadKeyPassword = System.getenv("GROOVEFOLIO_UPLOAD_KEY_PASSWORD")
val isReleaseBuild = gradle.startParameter.taskNames.any { it.contains("Release", ignoreCase = true) }
val hasUploadSigning = listOf(uploadKeystorePath, uploadKeyAlias, uploadStorePassword, uploadKeyPassword)
    .all { !it.isNullOrBlank() }

if (isReleaseBuild) {
    check(hasUploadSigning) {
        "Release signing requires GROOVEFOLIO_UPLOAD_KEYSTORE, GROOVEFOLIO_UPLOAD_KEY_ALIAS, " +
            "GROOVEFOLIO_UPLOAD_STORE_PASSWORD and GROOVEFOLIO_UPLOAD_KEY_PASSWORD."
    }
    check(file(uploadKeystorePath!!).isFile) { "Release signing keystore was not found." }
}

android {
    namespace = "app.groovefolio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.groovefolio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadSigning) {
            create("upload") {
                storeFile = file(uploadKeystorePath!!)
                storePassword = uploadStorePassword
                keyAlias = uploadKeyAlias
                keyPassword = uploadKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (hasUploadSigning) signingConfig = signingConfigs.getByName("upload")
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

dependencies {
    testImplementation("junit:junit:4.13.2")
}
