plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}
android {
    namespace = "com.example.sshtunnel"
    compileSdk = 34
    defaultConfig {
        applicationId = "com.example.sshtunnel"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }
    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions.jvmTarget = "17"
    buildFeatures.viewBinding = true
    packaging {
        resources {
            // jsch and Bouncy Castle both ship OSGI MANIFEST.MF in multi-release JARs (versions 9,11,15,17,21)
            for (v in listOf(9, 11, 15, 17, 21)) {
                pickFirsts += "META-INF/versions/$v/OSGI-INF/MANIFEST.MF"
            }
        }
    }
}
dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("com.google.android.material:material:1.11.0")
    implementation("androidx.constraintlayout:constraintlayout:2.1.4")
    implementation("androidx.lifecycle:lifecycle-runtime-ktx:2.6.2")
    implementation("androidx.lifecycle:lifecycle-service:2.6.2")
    // SSHJ: isolated channels (JSch dropped the whole session on long-lived forwarded traffic)
    implementation("com.hierynomus:sshj:0.38.0")
    implementation("org.bouncycastle:bcprov-jdk18on:1.78.1") // required for Ed25519 on Android
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
