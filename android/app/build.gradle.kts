import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.mekaar.mekaar_chat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.mekaar.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            val keystoreFile = file("mekaar_release.jks")
            val envPass: String? = System.getenv("KEYSTORE_PASSWORD")
            val propPass: String? = keystoreProperties.getProperty("storePassword")
            val pass = if (!envPass.isNullOrEmpty()) envPass else propPass

            if (keystoreFile.exists() && !pass.isNullOrEmpty()) {
                val envKeyPass: String? = System.getenv("KEY_PASSWORD")
                val propKeyPass: String? = keystoreProperties.getProperty("keyPassword")
                val keyPass = if (!envKeyPass.isNullOrEmpty()) envKeyPass else (propKeyPass ?: pass)

                val envAlias: String? = System.getenv("KEY_ALIAS")
                val propAlias: String? = keystoreProperties.getProperty("keyAlias")
                val alias = if (!envAlias.isNullOrEmpty()) envAlias else (propAlias ?: "mekaar")

                storeFile = keystoreFile
                storePassword = pass
                keyAlias = alias
                keyPassword = keyPass
            } else {
                val debugSigning = signingConfigs.getByName("debug")
                storeFile = debugSigning.storeFile
                storePassword = debugSigning.storePassword
                keyAlias = debugSigning.keyAlias
                keyPassword = debugSigning.keyPassword
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")
}
