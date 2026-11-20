allprojects {
    repositories {
        // Internal tooling (native-dev): inert unless OCTOPUS_ANDROID_DEV_REPO is set.
        // Then the whole Octopus group resolves from that dev build and from nowhere
        // else. Declared once, idempotently: two exclusive declarations for the same
        // group make it unresolvable, and the plugin's android/build.gradle carries
        // the same block for its standalone build.
        val octopusDevRepo = System.getenv("OCTOPUS_ANDROID_DEV_REPO")
        if (!octopusDevRepo.isNullOrEmpty() && findByName("octopusNativeDev") == null) {
            exclusiveContent {
                forRepository { maven { name = "octopusNativeDev"; url = uri(octopusDevRepo) } }
                filter { includeGroup("com.octopuscommunity") }
            }
        }
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
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
