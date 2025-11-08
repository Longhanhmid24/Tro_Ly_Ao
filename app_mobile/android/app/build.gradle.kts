plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.app_mobile"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.0.13004108"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.app_mobile"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
                arguments += listOf(
                    "-DANDROID_STL=c++_shared"
                )
            }
        }
    }

    androidResources {
        noCompress += listOf("tflite", "lite", "pt")
    }

    packaging {
        jniLibs {
            useLegacyPackaging = true
            excludes += setOf()
        }
        resources {
            excludes += setOf()
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }

        debug {
            isMinifyEnabled = false
        }
    }

    // ✅ TỰ ĐỘNG COPY ASSETS
    applicationVariants.all {
        val variant = this
        val variantName = variant.name.capitalize()

        tasks.register("copy${variantName}Assets") {
            doLast {
                println("📦 Copying YOLO model for variant: $variantName")

                val assetsDir = file("src/main/assets")
                if (!assetsDir.exists()) {
                    assetsDir.mkdirs()
                }

                copy {
                    from("../../assets")
                    include("model_face.tflite", "model_face.txt")
                    into(assetsDir)
                }

                println("✅ Model files copied to: ${assetsDir.absolutePath}")
            }
        }

        variant.mergeAssetsProvider.get().dependsOn("copy${variantName}Assets")
    }
}

flutter {
    source = "../.."
}