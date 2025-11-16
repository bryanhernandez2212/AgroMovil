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


