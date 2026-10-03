import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// ── Firma de release (clave de SUBIDA, nunca la debug) ─────────────────────
// android/key.properties NO se versiona (ver .gitignore y key.properties.example).
// Si el archivo no existe, el build de release FALLA con mensaje claro; los
// builds de debug/profile no lo requieren.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.repuestosya.app"
    compileSdk = 37
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.repuestosya.app"
        // versionCode/versionName vienen de pubspec.yaml (1.0.0+1): no tocar.
        minSdk = flutter.minSdkVersion
        targetSdk = 37
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Solo se rellena si existe key.properties; si no, el check de
            // abajo (taskGraph.whenReady) detiene el build de release antes
            // de firmar. Nunca se cae a la clave debug.
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // R8: minifica y elimina recursos sin usar. El código Dart se
            // ofusca aparte con --obfuscate (scripts/build_release.*); aquí
            // se protege el bytecode nativo (plugins).
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// Fail-fast SOLO en builds de release: si falta la clave de subida, se detiene
// la compilación con un mensaje claro en lugar de firmar con la clave debug.
// (Se usa TaskExecutionGraphListener en vez de taskGraph.whenReady, que en
// Kotlin DSL espera una Closure de Groovy y rompe el tipado del script.)
gradle.taskGraph.addTaskExecutionGraphListener(object : TaskExecutionGraphListener {
    override fun graphPopulated(graph: TaskExecutionGraph) {
        val pideRelease = graph.allTasks.any {
            it.name.startsWith("assembleRelease") ||
                it.name.startsWith("bundleRelease") ||
                it.name.startsWith("packageRelease")
        }
        if (pideRelease && !keystorePropertiesFile.exists()) {
            throw GradleException(
                "Firma de release NO configurada: falta android/key.properties.\n" +
                    "  1. Genera la clave de SUBIDA (upload key) FUERA del repo: ver docs/FIRMA_Y_RELEASE.md\n" +
                    "     (keytool -genkeypair -v -keystore <fuera-del-repo>/repuestosya-upload.jks " +
                    "-keyalg RSA -keysize 2048 -validity 10000 -alias upload)\n" +
                    "  2. Copia android/key.properties.example -> android/key.properties y completa los valores.\n" +
                    "El build de release se detiene: NUNCA se firma con la clave debug."
            )
        }
    }
})

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
