# Flutter Application 1

Guia para desarrollar y probar esta app movil con Flutter desde cero.

## 1. Que necesitas instalar

En Linux necesitas:

1. **Flutter SDK**: descargalo desde [flutter.dev](https://docs.flutter.dev/get-started/install/linux).
2. **Android Studio**: incluye el Android SDK, las herramientas de compilacion y el emulador.
3. **VS Code** (recomendado) con las extensiones **Flutter** y **Dart**.
4. Un **emulador Android** o un telefono Android conectado por USB.

Despues de instalar todo, abre una terminal y ejecuta:

```bash
flutter doctor
```

Este comando revisa la instalacion y muestra que falta. Lee las lineas con una `X` o un `!` y corrige primero los problemas del Flutter SDK y del Android toolchain. Para aceptar las licencias de Android:

```bash
flutter doctor --android-licenses
```

Comprueba que Flutter detecta algun dispositivo:

```bash
flutter devices
```

## 2. Abrir y preparar el proyecto

Abre en VS Code la carpeta raiz del proyecto, la que contiene `pubspec.yaml`. Desde una terminal situada en esa carpeta ejecuta:

```bash
flutter pub get
```

`pubspec.yaml` describe el proyecto y sus dependencias. `flutter pub get` descarga esas dependencias; normalmente solo debes repetirlo despues de cambiar ese archivo.

## 3. Ejecutar la app

Inicia un emulador desde Android Studio o conecta un telefono con la depuracion USB activada. Luego ejecuta:

```bash
flutter run
```

Si hay mas de un dispositivo, Flutter pedira elegir uno. Tambien puedes seleccionar el dispositivo en la esquina inferior derecha de VS Code y pulsar **Run > Start Debugging** o `F5`.

Para probar el registro desde un telefono Android conectado por USB, deja el backend levantado y crea el tunel ADB:

```bash
docker compose up -d db
npm start
adb reverse tcp:8080 tcp:8080
flutter run
```

La app usa `http://127.0.0.1:8080` por defecto, que mediante `adb reverse` apunta al backend del ordenador. Para un emulador Android usa:

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

### Recarga rapida durante el desarrollo

Con `flutter run` activo:

- `r`: **hot reload**. Aplica cambios de codigo conservando el estado, por ejemplo el valor del contador.
- `R`: **hot restart**. Reinicia el estado de la app.
- `q`: detiene la ejecucion.

En VS Code puedes usar los botones de recarga de la barra de depuracion. Si modificas `pubspec.yaml`, assets o configuracion nativa, detente y vuelve a ejecutar la app.

## 4. Como esta organizada

| Ruta | Para que sirve |
| --- | --- |
| `lib/main.dart` | Punto de entrada y widgets de la app actual. |
| `test/widget_test.dart` | Prueba automatizada del contador. |
| `pubspec.yaml` | Nombre, version, dependencias y assets. |
| `android/` | Configuracion especifica de Android. |
| `ios/` | Configuracion especifica de iOS. Requiere macOS y Xcode para compilar iOS. |
| `analysis_options.yaml` | Reglas de analisis y estilo de Dart. |

El flujo basico de Flutter es:

1. `main()` llama a `runApp`.
2. `MyApp` define el tema y la pantalla inicial.
3. `MyHomePage` es un `StatefulWidget` porque su contenido cambia.
4. `_counter` guarda el estado.
5. `setState` avisa a Flutter de que debe volver a dibujar la pantalla.

Los elementos de la interfaz se llaman **widgets**. `Scaffold` proporciona la estructura de una pantalla, `AppBar` la barra superior, `Column` organiza elementos en vertical y `FloatingActionButton` representa el boton flotante.

## 5. Probar la app

### Prueba automatizada

Ejecuta todas las pruebas desde la raiz:

```bash
flutter test
```

La prueba actual:

1. Construye `MyApp` sin abrir un emulador.
2. Comprueba que el contador empieza en `0`.
3. Pulsa el boton `+`.
4. Comprueba que el contador cambia a `1`.

Para ejecutar solo esta prueba:

```bash
flutter test test/widget_test.dart
```

Cuando agregues una funcionalidad, actualiza o crea una prueba que compruebe su comportamiento observable. Una prueba no debe depender de que el texto o el numero "parezcan correctos": debe verificar una accion y su resultado.

### Analisis y formato

Antes de guardar cambios importantes, ejecuta:

```bash
dart format lib test
flutter analyze
```

`dart format` ordena el codigo. `flutter analyze` detecta errores y problemas de estilo sin necesidad de ejecutar la app.

## 6. Crear un cambio paso a paso

Para modificar la app:

1. Abre `lib/main.dart`.
2. Cambia una cosa pequena, por ejemplo el texto del `AppBar`.
3. Guarda el archivo y observa el hot reload.
4. Si agregas un boton o una pantalla, dale una `Key` o un texto identificable para poder encontrarlo desde una prueba.
5. Ejecuta `flutter test` y `flutter analyze`.
6. Prueba manualmente el flujo completo en un emulador o telefono.

No edites los archivos generados dentro de `build/` o `.dart_tool/`; Flutter los recrea automaticamente.

## 7. Generar una version instalable

Para generar un APK de prueba:

```bash
flutter build apk --debug
```

El APK se crea en `build/app/outputs/flutter-apk/`.

Para una version optimizada de distribucion:

```bash
flutter build apk --release
```

Una version `release` requiere configurar la firma de Android antes de publicarla. No compartas una compilacion release sin revisar esa configuracion y la version definida en `pubspec.yaml`.

## 8. Problemas frecuentes

- **No hay dispositivos**: inicia un emulador, conecta el telefono y ejecuta `flutter devices`.
- **`flutter` no se encuentra**: agrega la carpeta `bin` del Flutter SDK al `PATH` y reinicia la terminal.
- **Faltan licencias Android**: ejecuta `flutter doctor --android-licenses`.
- **La pantalla no cambia**: confirma que el cambio esta dentro del widget correcto; para cambios de estado usa `setState`.
- **La prueba no encuentra un boton**: usa `find.byIcon(Icons.add)`, `find.text('...')` o agrega una `Key` estable.
- **El hot reload falla**: detiene la app y vuelve a ejecutar `flutter run`; algunos cambios de configuracion necesitan reinicio completo.

## Enlaces utiles

- [Instalacion de Flutter en Linux](https://docs.flutter.dev/get-started/install/linux)
- [Aprender Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Pruebas en Flutter](https://docs.flutter.dev/testing)
- [Documentacion de Flutter](https://docs.flutter.dev/)
