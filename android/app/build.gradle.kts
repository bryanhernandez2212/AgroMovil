import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

// ==============================================================================
// CONFIGURACIÓN DEL KEYSTORE PARA FIRMA DE RELEASE
// ==============================================================================
// Carga las propiedades del keystore desde 'android/key.properties'.
// Si el archivo existe y está configurado correctamente, usará el keystore de producción.
// Si NO existe o hay errores, usará automáticamente el debug keystore.
//
// NOTA: El keystore está configurado en android/key.properties
// ==============================================================================
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    try {
        keystorePropertiesFile.inputStream().use {
            keystoreProperties.load(it)
        }
        println("✅ key.properties cargado correctamente")
    } catch (e: Exception) {
        // Si hay error al leer el archivo, continuar sin él (usará debug keystore)
        println("⚠️ No se pudo cargar key.properties: ${e.message}")
        println("⚠️ Se usará el debug keystore para esta compilación")
    }
} else {
    println("ℹ️ key.properties no existe. Se usará el debug keystore")
}

android {
    namespace = "com.bryan.agromarket"
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
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.bryan.agromarket"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Configuración de firma para debug
        getByName("debug") {
            // Esta es la configuración por defecto de debug
        }
        
        // Configuración de release usando key.properties si existe
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
        
        // Configuración "externalOverride" para compatibilidad
        create("externalOverride") {
            if (keystorePropertiesFile.exists()) {
                // Usar keystore de producción si existe
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            } else {
                // Fallback a debug keystore si no hay key.properties
                val debugConfig = signingConfigs.getByName("debug")
                storeFile = debugConfig.storeFile
                storePassword = debugConfig.storePassword ?: "android"
                keyAlias = debugConfig.keyAlias ?: "androiddebugkey"
                keyPassword = debugConfig.keyPassword ?: "android"
            }
        }
    }

    buildTypes {
        release {
            // Usar keystore de producción si existe, sino usar debug para pruebas
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // Habilitar minify para poder aplicar reglas de ProGuard/R8 cuando sea necesario
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    packaging {
        resources {
            // Excluir archivos duplicados que causan conflictos
            excludes += "/META-INF/{AL2.0,LGPL2.1}"
            pickFirsts += "**/libc++_shared.so"
            pickFirsts += "**/libjsc.so"
            // Resolver conflictos de clases duplicadas de androidx.activity.compose
            pickFirsts += "**/androidx/activity/compose/R.class"
            pickFirsts += "**/androidx/activity/compose/R\$*.class"
            pickFirsts += "**/META-INF/androidx.activity.activity-compose.kotlin_module"
            pickFirsts += "**/META-INF/androidx.activity.activity-ktx.kotlin_module"
            // Excluir módulos duplicados
            excludes += "META-INF/androidx.activity.activity-compose.kotlin_module"
            excludes += "META-INF/androidx.activity.activity-ktx.kotlin_module"
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // MaterialComponents requerido para flutter_stripe
    implementation("com.google.android.material:material:1.11.0")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

// Configuración para resolver conflictos de dependencias duplicadas
configurations.all {
    resolutionStrategy {
        // Forzar una única versión de androidx.activity para evitar duplicados
        eachDependency {
            if (requested.group == "androidx.activity") {
                if (requested.name == "activity-compose" || requested.name == "activity-ktx" || requested.name == "activity") {
                    useVersion("1.9.2")
                    because("Resolver conflictos de dependencias duplicadas de androidx.activity")
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
