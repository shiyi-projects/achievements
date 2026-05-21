pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.11.1" apply false
    // KGP 声明保留(版本满足 Flutter 要求),flutter_timezone 等仍依赖 KGP 的
    // plugin 需要在 root 类路径上能解析到。本 app 已迁移到 Built-in Kotlin,
    // 不再在 app/build.gradle.kts 里 apply 它。
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

include(":app")
