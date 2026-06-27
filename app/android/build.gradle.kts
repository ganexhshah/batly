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

subprojects {
    fun configureNamespace(proj: Project) {
        val android = proj.extensions.findByType<com.android.build.gradle.BaseExtension>()
        if (android != null && android.namespace == null) {
            val groupPath = proj.group.toString()
            android.namespace = if (groupPath.isNotEmpty() && groupPath != "unspecified") {
                groupPath
            } else {
                "com.example.${proj.name.replace("-", "_")}"
            }
        }
    }

    if (project.state.executed) {
        configureNamespace(project)
    } else {
        project.afterEvaluate {
            configureNamespace(project)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
