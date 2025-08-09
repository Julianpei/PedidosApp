# Cómo obtener tu APK automáticamente con GitHub Actions

1) Creá un repositorio en GitHub (o usá uno existente).
2) Subí la carpeta del proyecto `PedidosApp` tal como está.
3) Asegurate de tener este archivo: `.github/workflows/build-android.yml` (ya está incluido).
4) Hacé un commit/push a la rama `main` o `master`.
5) En tu repo, entrá a **Actions** → verás correr el workflow **Build Android APK (Debug)**.
6) Cuando termine, entrá al run y descargá el **Artifact** llamado `app-debug-apk`.
7) Dentro está el archivo **app-debug.apk** listo para instalar en tu Android.

> Este APK de *debug* sirve para instalar en tu teléfono. Para publicar en Google Play se usa un APK/AAB de *release* con firma propia; si lo necesitás, te preparo ese flujo también.
