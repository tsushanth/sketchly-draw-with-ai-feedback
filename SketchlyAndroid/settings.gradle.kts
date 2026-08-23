pluginManagement {
    repositories {
        google {
            content {
                includeGroupByRegex("com\\.android.*")
                includeGroupByRegex("com\\.google.*")
                includeGroupByRegex("androidx.*")
            }
        }
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
        maven { url = uri("https://jitpack.io") } // required by PaywallKit's transitive SpinWheelCompose dep
    }
}

rootProject.name = "SketchlyAndroid"
include(":app")
include(":paywallkit")
project(":paywallkit").projectDir = file("/Users/sushanthtiruvaipati/Documents/GitHub/PaywallKit-Android/paywallkit")
