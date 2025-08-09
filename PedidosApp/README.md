# PedidosApp (Flutter)

App sencilla para crear pedidos a proveedores a nombre de un cliente,
usando catálogos de **Clientes**, **Proveedores** y **Materiales**.
Permite **compartir** el pedido por WhatsApp/Email usando el texto del pedido.

## Funciones
- CRUD de Clientes, Proveedores y Materiales (en el dispositivo).
- Crear Pedido: elegir Cliente, Proveedor y agregar Materiales con cantidades.
- Compartir Pedido por WhatsApp/Email (share sheet).
- Datos guardados localmente en el dispositivo (SharedPreferences).

## Requisitos para compilar (Android APK)
1. Instalar Flutter: https://docs.flutter.dev/get-started/install
2. `flutter doctor` debe quedar en verde.
3. En la carpeta del proyecto:
   ```bash
   flutter pub get
   flutter build apk --release
   ```
4. APK resultante: `build/app/outputs/flutter-apk/app-release.apk`

> Si no tenés entorno, pasá esta carpeta a un desarrollador y en minutos te genera el APK.
