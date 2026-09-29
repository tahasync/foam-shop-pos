plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // firebase-perf is auto-applied by the Flutter plugin — do NOT declare here
    // END: FlutterFire Configuration
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.asif.foamshop"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.asif.foamshop"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            val ksPath = System.getenv("KEYSTORE_PATH") ?: rootProject.findProperty("KEYSTORE_PATH")?.toString()
            if (!ksPath.isNullOrEmpty()) {
                storeFile = file(ksPath)
                storePassword = System.getenv("KEYSTORE_PASSWORD") ?: rootProject.findProperty("KEYSTORE_PASSWORD")?.toString() ?: ""
                keyAlias = System.getenv("KEY_ALIAS") ?: rootProject.findProperty("KEY_ALIAS")?.toString() ?: ""
                keyPassword = System.getenv("KEY_PASSWORD") ?: rootProject.findProperty("KEY_PASSWORD")?.toString() ?: ""
                println("Using release signing config: $ksPath")
            } else {
                println("WARNING: KEYSTORE_PATH not set — release builds will use debug signing")
            }
        }
    }

    buildTypes {
        release {
            val ksPath = System.getenv("KEYSTORE_PATH")
                ?: rootProject.findProperty("KEYSTORE_PATH")?.toString()
            val hasKs = !ksPath.isNullOrEmpty()

            // A release that is quietly debug-signed is the worst outcome here:
            // it installs, it runs, it looks fine, and it is the artefact someone
            // eventually ships. Previously this printed a WARNING and carried on
            // producing a debug-signed APK, so the only signal was a line in a
            // build log nobody was reading.
            //
            // A release build now REFUSES to produce an unsigned-for-production
            // artefact unless the override is passed deliberately. The override
            // exists because the CI path and local verification genuinely do
            // sometimes need a release-mode build without the production key -
            // it just has to be asked for by name instead of happening by
            // accident.
            val allowDebugSigning = (project.findProperty("allowDebugSigning") as String?)?.toBoolean() ?: false

            // Only enforce this when a RELEASE is actually being assembled.
            //
            // Gradle CONFIGURES every declared buildType when it loads the
            // project, whether or not that variant is being built. So a `throw`
            // placed directly in this block runs during a plain
            // `flutter build apk --debug` and kills the debug build with a
            // message about release signing. That is the wrong failure in the
            // worst way: it makes the safe, local, development build impossible
            // and pushes someone towards the release override flag to get their
            // day-to-day work done.
            //
            // `startParameter.taskNames` is the requested task list
            // ("assembleDebug", "assembleRelease", "bundleRelease", ...).
            val tasks = gradle.startParameter.taskNames.map { it.lowercase() }
            val buildingRelease = tasks.any {
                it.contains("release") || it.contains("bundle")
            }

            if (buildingRelease && !hasKs && !allowDebugSigning) {
                throw GradleException(
                    """
                    |REFUSING TO BUILD A DEBUG-SIGNED RELEASE.
                    |
                    |This would produce an APK signed with the local debug key. It installs
                    |and runs, so the problem is easy to miss - but Play Store rejects it,
                    |it is not the key the already-published build used (so it cannot be
                    |installed as an update over it), and it is not a production artefact.
                    |
                    |To sign properly, set:
                    |  KEYSTORE_PATH       path to release.keystore
                    |  KEYSTORE_PASSWORD   keystore password
                    |  KEY_ALIAS           key alias (default: upload)
                    |  KEY_PASSWORD        key password (defaults to KEYSTORE_PASSWORD)
                    |
                    |To build a release-mode APK for LOCAL VERIFICATION ONLY, pass:
                    |  flutter build apk --release -PallowDebugSigning=true
                    |
                    |That artefact must never be published.
                    """.trimMargin()
                )
            }

            signingConfig = if (hasKs) {
                signingConfigs.getByName("release")
            } else {
                logger.warn(
                    "Building a DEBUG-SIGNED release because -PallowDebugSigning=true was " +
                        "passed. This artefact must never be published."
                )
                signingConfigs.getByName("debug")
            }

            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
