plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.agromarket"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.agromarket"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    packaging {
        resources {
            // Excluir archivos duplicados que causan conflictos
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            pickFirsts += "**/libc++_shared.so"
            pickFirsts += "**/libjsc.so"
            // Resolver conflictos de clases duplicadas
            pickFirsts += "**/androidx/activity/compose/R.class"
            pickFirsts += "**/androidx/activity/compose/R\$*.class"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // MaterialComponents requerido para flutter_stripe
    implementation("com.google.android.material:material:1.11.0")
}

// Configuración para resolver conflictos de dependencias duplicadas
configurations.all {
    resolutionStrategy {
        // Forzar una única versión de androidx.activity para evitar duplicados
        eachDependency {
            if (requested.group == "androidx.activity") {
                if (requested.name == "activity-compose" || requested.name == "activity-ktx") {
                    useVersion("1.9.2")
                    because("Resolver conflictos de dependencias duplicadas")
                }
            }
        }
        // Preferir la primera versión encontrada
        force("androidx.activity:activity:1.9.2")
        force("androidx.activity:activity-compose:1.9.2")
        force("androidx.activity:activity-ktx:1.9.2")
    }
}

// Suprimir advertencias de APIs deprecadas (no afectan la funcionalidad)
tasks.withType<JavaCompile> {
    options.compilerArgs.addAll(listOf("-Xlint:-options", "-Xlint:-deprecation"))
}
