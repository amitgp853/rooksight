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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// Stockfish runs about 17x slower when compiled without optimisation, which
// makes debug builds unplayable. Build the engine plugins as Release even in
// debug builds (their CMake files switch on -O3 and NDEBUG for anything but
// Debug). The iOS side of this is in ios/Podfile.
subprojects {
    if (name.startsWith("multistockfish")) {
        pluginManager.withPlugin("com.android.library") {
            extensions.getByName("android").withGroovyBuilder {
                "buildTypes" {
                    "getByName"("debug") {
                        "externalNativeBuild" {
                            "cmake" {
                                "arguments"("-DCMAKE_BUILD_TYPE=Release")
                            }
                        }
                    }
                }
            }
        }
    }
}
