# Règles R8/ProGuard SparkWork — indispensables en build release minifié.
# Sans elles, R8 supprime des classes chargées par réflexion par les SDK
# natifs → crashs silencieux uniquement en release.

# ── RevenueCat (purchases_flutter) + Google Play Billing ──────────────────
-keep class com.revenuecat.** { *; }
-keep class com.android.billingclient.** { *; }

# ── Veriff (vérification d'identité) ──────────────────────────────────────
-keep class com.veriff.** { *; }
-keep class mobi.lab.veriff.** { *; }
-dontwarn com.veriff.**

# ── flutter_local_notifications (désérialisation Gson par réflexion) ──────
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# ── Firebase / Google Play Services (règles consumer généralement
#    embarquées, on sécurise les entrées critiques) ───────────────────────
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# ── Kotlin coroutines / OkHttp (transitives Veriff) ───────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn org.conscrypt.**
-dontwarn kotlinx.coroutines.**
