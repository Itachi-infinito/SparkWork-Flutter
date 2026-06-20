allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Some older plugins (e.g. veriff_flutter) don't declare an AGP `namespace`,
// which AGP 8+ requires. Backfill it from their AndroidManifest.xml `package` attribute.
// Skip ":app" — its evaluation is forced early by evaluationDependsOn above,
// so it is already evaluated by the time this callback would be registered.
subprojects {
    if (name == "app") return@subprojects
    afterEvaluate {
        val androidExt = extensions.findByName("android")
        if (androidExt is com.android.build.gradle.BaseExtension) {
            if (androidExt.namespace == null) {
                val manifestFile = file("src/main/AndroidManifest.xml")
                if (manifestFile.exists()) {
                    val pkg = groovy.xml.XmlParser().parse(manifestFile).attribute("package") as String?
                    if (pkg != null) {
                        androidExt.namespace = pkg
                    }
                }
            }

            // Some older plugins don't pin a JVM target, leaving javac at an
            // older version while the Kotlin compiler defaults to the host
            // JDK's version. AGP reads compatibility from this extension
            // (not from the JavaCompile task directly), so set it here.
            androidExt.compileOptions.sourceCompatibility = JavaVersion.VERSION_17
            androidExt.compileOptions.targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
