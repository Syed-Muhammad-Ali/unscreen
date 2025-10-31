import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.unscreen.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.unscreen.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val keyAliasValue = keystoreProperties["keyAlias"]?.toString()
            val keyPasswordValue = keystoreProperties["keyPassword"]?.toString()
            val storeFileValue = keystoreProperties["storeFile"]?.toString()
            val storePasswordValue = keystoreProperties["storePassword"]?.toString()

            if (
                !keyAliasValue.isNullOrEmpty() &&
                !keyPasswordValue.isNullOrEmpty() &&
                !storeFileValue.isNullOrEmpty() &&
                !storePasswordValue.isNullOrEmpty()
            ) {
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeFile = file(storeFileValue)
                storePassword = storePasswordValue
                println("✅ Release signing config loaded successfully.")
            } else {
                println("⚠️ Missing or invalid keystore properties. Using debug signing.")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
