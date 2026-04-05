plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ─── 从 pubspec.yaml 自动读取版本，单一来源不再需要手动同步 ───
fun parsePubspecVersion(): Pair<String, Int> {
    val pubspec = rootProject.file("../../pubspec.yaml")
    if (!pubspec.exists()) return Pair("2.2.3", 17)
    val versionLine = pubspec.readLines().firstOrNull { it.trimStart().startsWith("version:") }
        ?: return Pair("2.2.3", 17)
    // 格式: version: 2.2.3+17
    val raw = versionLine.substringAfter("version:").trim()
    return if (raw.contains("+")) {
        val name = raw.substringBefore("+").trim()
        val code = raw.substringAfter("+").trim().toIntOrNull() ?: 17
        Pair(name, code)
    } else {
        Pair(raw, 17)
    }
}

val (appVersionName, appVersionCode) = parsePubspecVersion()

android {
    namespace = "com.glassmusic.glass_music"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.glassmusic.glass_music"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = appVersionCode          // 从 pubspec.yaml 自动读取
        versionName = appVersionName          // 从 pubspec.yaml 自动读取
        multiDexEnabled = true
        manifestPlaceholders["appLabel"] = "吾爱Music"  // 统一应用名称
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            isCrunchPngs = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // 单一 APK，根据设备自动切换 UI（不再使用 flavor 分离）
    // flavorDimensions 已移除，应用名称在 AndroidManifest.xml 中统一为"吾爱Music"

    // Rename APK output: WuAiMusic-2.2.4-build18-arm64.apk (支持 split-per-abi)
    applicationVariants.all {
        val variant = this
        variant.outputs
            .map { it as com.android.build.gradle.internal.api.BaseVariantOutputImpl }
            .forEach { output ->
                val abiFilter = output.getFilter("ABI")
                val abiSuffix = if (abiFilter != null) "-$abiFilter" else ""
                val buildType = variant.buildType.name
                val suffix = if (buildType == "release") "" else "-$buildType"
                output.outputFileName = "WuAiMusic-${appVersionName}-build${appVersionCode}${abiSuffix}${suffix}.apk"
            }
    }
}

flutter {
    source = "../.."
}
