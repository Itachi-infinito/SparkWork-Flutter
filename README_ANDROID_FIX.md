# Correctif Android — `veriff_flutter` (namespace + JVM target)

Ce document explique un problème de build Android rencontré en intégrant
`veriff_flutter` et comment le correctif fonctionne, pour pouvoir le
reproduire (ou le retirer si une version corrigée du plugin sort un jour).

## Le problème

Le projet utilise AGP (Android Gradle Plugin) **8.11.1** et Kotlin
**2.2.20**. Le plugin `veriff_flutter` (version 2.2.0, dernière compatible
avec l'API actuelle, voir `pubspec.yaml`) a été publié pour une toolchain
beaucoup plus ancienne (AGP 7.0.4, syntaxe Groovy `apply plugin:`) et son
`android/build.gradle` :

1. **Ne déclare aucun `namespace`** — obligatoire depuis AGP 8. Sans lui :

   ```
   A problem occurred configuring project ':veriff_flutter'.
   > Namespace not specified. Specify a namespace in the module's build
     file: .../veriff_flutter-2.2.0/android/build.gradle.
   ```

2. **Ne fixe pas de cible JVM cohérente** entre javac et le compilateur
   Kotlin. Une fois le namespace corrigé, l'erreur suivante apparaît :

   ```
   Execution failed for task ':veriff_flutter:compileDebugKotlin'.
   > Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks
     Inconsistent JVM-target compatibility detected for tasks
     'compileDebugJavaWithJavac' (1.8) and 'compileDebugKotlin' (21).
   ```

   (Le même problème touche aussi d'autres plugins anciens du projet —
   `flutter_image_compress_common` notamment — donc le correctif est
   générique, pas un hack spécifique à Veriff.)

Modifier directement les fichiers du plugin dans le pub cache n'est pas une
option viable : ils sont régénérés à chaque `flutter pub get` et ne sont pas
versionnés avec le projet.

## Le correctif

Tout est dans **un seul fichier**, déjà commité :
**`android/build.gradle.kts`** (racine du module `android/`, pas
`android/app/build.gradle.kts`).

Bloc ajouté à la fin du fichier (après la configuration `newBuildDir`
existante) :

```kotlin
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
```

### Pourquoi ça fonctionne

- **Namespace** : AGP exige un `namespace` sur chaque module Android
  (anciennement dérivé du `package="..."` de l'`AndroidManifest.xml`, ce
  comportement a été supprimé en AGP 8). Le bloc lit ce `package` directement
  dans le manifeste du plugin et le réinjecte comme `namespace`, sans toucher
  au fichier du plugin lui-même.
- **JVM target** : on force `sourceCompatibility`/`targetCompatibility` à 17
  sur l'extension `android {}` de **chaque sous-projet** (c'est la source de
  vérité qu'AGP utilise pour configurer ses tâches `JavaCompile` — modifier
  directement la tâche ne suffit pas, AGP la recalcule depuis l'extension) et
  on force le compilateur Kotlin à cibler 17 également via
  `tasks.withType<KotlinCompile>()`.
- **Exclusion de `:app`** : le bloc existant
  `subprojects { project.evaluationDependsOn(":app") }` force le module
  `:app` à être évalué en premier. Si notre callback `afterEvaluate` tentait
  de s'enregistrer sur `:app` après coup, Gradle lève
  `Cannot run Project.afterEvaluate(Action) when the project is already
  evaluated`. Le module `:app` a de toute façon déjà son propre `namespace`
  et son `compileOptions` corrects dans `android/app/build.gradle.kts` — il
  n'a pas besoin de ce correctif.

## Si tu changes de machine de développement

Aucune action manuelle n'est requise — le correctif vit dans
`android/build.gradle.kts`, qui est versionné avec le projet. Il suffit de :

```bash
git clone <repo>
cd sparkwork
flutter pub get
flutter run
```

**Seul prérequis** : `cloudbuild.googleapis.com` doit être autorisé pour le
compte de service Cloud Build du projet Firebase (`sparkwork-f41ec`), sinon
le tout premier déploiement de Cloud Functions échoue avec une erreur de
permission. Si besoin :

1. Console Google Cloud → IAM & Admin → IAM →
   `https://console.cloud.google.com/iam-admin/iam?project=sparkwork-f41ec`
2. "Accorder l'accès" → principal `937376123870@cloudbuild.gserviceaccount.com`
   → rôle "Compte de service Cloud Build"
3. Relancer `firebase deploy --only functions`

(Ce n'est lié à Veriff que par coïncidence temporelle — c'est une étape de
configuration Google Cloud one-shot par projet, pas par machine.)

## Si une nouvelle version de `veriff_flutter` corrige le problème

Vérifier dans le changelog du package si `android/build.gradle` déclare
désormais un `namespace` et une `compileOptions`/`kotlinOptions` cohérente.
Si oui, le bloc ci-dessus devient un no-op silencieux (les conditions
`if (androidExt.namespace == null)` ne s'appliqueront plus) — **il n'est pas
nécessaire de le retirer immédiatement**, mais il peut être supprimé pour
nettoyer une fois confirmé que tous les plugins du projet déclarent
correctement leur configuration.
