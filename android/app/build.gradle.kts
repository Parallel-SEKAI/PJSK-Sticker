// 补充必要的Java类导入
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 加载签名配置文件（Kotlin语法）
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        load(FileInputStream(keystorePropertiesFile)) // 现在能正确识别Properties和FileInputStream
    }
}

android {
    namespace = "org.parallel_sekai.pjsk_sticker"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "org.parallel_sekai.pjsk_sticker"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 签名配置（Kotlin语法）
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
            storeFile = if (keystoreProperties["storeFile"] != null) {
                file(keystoreProperties["storeFile"] as String)
            } else null
            storePassword = keystoreProperties["storePassword"] as String?
        }
    }

    // 构建类型（Kotlin语法）
    buildTypes {
        getByName("release") {
            // 只有在签名配置有效的情况下才使用它
            signingConfig = if (signingConfigs["release"]?.keyAlias != null && 
                               signingConfigs["release"]?.storeFile != null) {
                signingConfigs["release"]
            } else {
                null
            }
        }
    }
}

flutter {
    source = "../.."
}
