############################
# Reglas para Stripe / R8  #
############################

# Suprime avisos por clases opcionales de Push Provisioning que pueden no estar presentes
-dontwarn com.stripe.android.pushProvisioning.**
-dontwarn com.reactnativestripesdk.pushprovisioning.**

# Evita que R8 elimine tipos internos si están presentes en el artefacto
-keep class com.stripe.android.pushProvisioning.** { *; }

# Mantener clases de Stripe principales (defensivo)
-keep class com.stripe.android.** { *; }

############################
# Reglas para Firebase      #
############################

# Firebase Core
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.internal.firebase-auth-api.** { *; }

# Firebase Firestore
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.cloud.firestore.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.iid.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }

# Gson para Firebase (si se usa)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

############################
# Reglas para AdMob         #
############################

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# Mantener clases de anuncios
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.ads.** { *; }

# Mantener métodos de AdMob
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

############################
# Reglas para Flutter       #
############################

# Mantener clases de Flutter
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Mantener clases de plugins de Flutter
-keep class dev.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

############################
# Reglas para HTTP y Cloud Functions #
############################

# Mantener todas las clases de servicios de agromarket
-keep class agromarket.services.** { *; }
-keep class agromarket.controllers.** { *; }
-keep class agromarket.models.** { *; }

# Mantener métodos estáticos de servicios (importante para FirebaseService)
-keepclassmembers class agromarket.services.FirebaseService {
    public static *;
    public *;
}

-keepclassmembers class agromarket.services.EmailService {
    public static *;
    public *;
}

# Mantener clases de package http (usado para Cloud Functions)
-keep class io.flutter.plugins.connectivity.** { *; }
-keep class io.flutter.plugins.** { *; }

# Mantener clases de JSON
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Mantener clases serializables
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Mantener clases de excepciones
-keep class * extends java.lang.Exception
-keep class dart.async.TimeoutException { *; }
-keep class dart.io.SocketException { *; }
-keep class dart.io.HttpException { *; }

# Mantener clases de Uri
-keep class dart.core.Uri { *; }

# No ofuscar nombres de métodos que se usan con reflection
-keepnames class * {
    @dart.core.JsonSerializable *;
}

# Mantener clases de Flutter que manejan HTTP
-keep class io.flutter.plugins.connectivity.** { *; }

############################
# Reglas para Google Play Core (componentes diferidos - opcionales) #
############################

# Suprimir advertencias de Google Play Core que son opcionales
# Estas clases solo se necesitan si usas componentes diferidos de Flutter
# Como no estás usando componentes diferidos, podemos suprimir estas advertencias

-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Suprimir específicamente las clases que R8 está buscando pero no están disponibles
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# Si estas clases estuvieran disponibles, las manteneríamos
# Pero como son opcionales y no están en el classpath, solo suprimimos las advertencias

############################
# Reglas generales          #
############################

# Mantener clases serializables
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Mantener métodos nativos
-keepclasseswithmembernames class * {
    native <methods>;
}

# Mantener clases de enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Mantener clases Parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Mantener clases R (recursos)
-keep class **.R$* {
    *;
}

# Mantener clases de excepciones
-keep public class * extends java.lang.Exception

# No optimizar clases anotadas con @Keep
-keep @androidx.annotation.Keep class *
-keepclassmembers class * {
    @androidx.annotation.Keep *;
}

