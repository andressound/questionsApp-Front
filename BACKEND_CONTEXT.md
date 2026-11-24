# Contexto de backend para QuestionsApp

Contrato entre la app Flutter y el backend (`/home/andres/Documentos/questionsapp/backend`, Node.js + Express 5 + PostgreSQL). Sirve para trabajar en el backend sin abrir el proyecto Flutter. Revisado contra el código de ambos el 2026-10-26.

## 1. Resumen del producto

App móvil de preguntas de opción múltiple:

- Inicio de sesión con usuario o correo y registro.
- Inicio: puesto, puntos y retos respondidos; camino con los 5 retos del día; acceso al reto semanal; clasificación.
- Retos: reto semanal (10 preguntas seguidas) y camino con los retos diarios, que se juegan en orden (los siguientes quedan bloqueados hasta responder el anterior).
- Pregunta: 15 segundos, cuatro opciones y resultado que decide el servidor.
- Perfil: puntos, retos, puesto, recorrido de hoy, edición de nombre de usuario y correo, y cierre de sesión.

Todos los datos que muestra la app vienen del backend; no quedan datos de demostración.

## 2. Entorno y URL base

La app lee la URL del backend de la constante de compilación `API_BASE_URL`. Valor predeterminado:

```text
http://127.0.0.1:8080
```

| Escenario | Cómo conectar |
| --- | --- |
| Dispositivo Android por USB | `adb reverse tcp:8080 tcp:8080` y el valor por defecto |
| Emulador Android | `--dart-define=API_BASE_URL=http://10.0.2.2:8080` |
| Dispositivo en la misma red wifi | `--dart-define=API_BASE_URL=http://IP_DEL_ORDENADOR:8080` |
| iOS Simulator | Valor por defecto |
| Staging o producción | URL HTTPS del entorno |

El backend escucha en `0.0.0.0:8080` (variable `PORT`), así que también es accesible desde la red local.

## 3. Requisitos generales de la API

- Base path: `/api`, salvo `GET /health`.
- JSON UTF-8 en peticiones y respuestas, con `Content-Type: application/json`. Cuerpos de más de `10kb` se rechazan con `413`.
- Los nombres de campos y rutas van en español y deben respetarse exactamente.
- Todas las rutas salvo `register`, `login` y `/health` exigen `Authorization: Bearer <token>` (sección 5). El usuario sale del token: nunca se envía `usuarioId`.
- CORS abierto (`cors()`), útil si se añade Flutter Web. Sin cabecera `X-Powered-By`.
- La respuesta correcta de una pregunta nunca se envía antes de que el usuario responda.

## 4. Endpoints

### 4.1 Objeto usuario

Lo devuelven `register`, `login` y `me`:

```json
{
  "id": 7,
  "username": "laura",
  "email": "laura@example.com",
  "puntos_totales": 12,
  "retos_completados": 4,
  "racha_actual": 3,
  "racha_maxima": 8,
  "rol": "estudiante"
}
```

- `puntos_totales`: suma de los `puntos` de las preguntas acertadas más el bonus de racha (`intentos.puntos_bonus`).
- `retos_completados`: número de preguntas respondidas (acertadas o no, diarias y semanales).
- `racha_actual`: días seguidos con el reto diario completado (las 5 preguntas). Sigue viva si el último día completado es hoy o ayer; si se salta un día vuelve a 0. `register` devuelve 0.
- `racha_maxima`: la racha más larga del usuario.
- `rol`: `"estudiante"`, `"profesor"` o `"admin"` (columna `usuarios.role` en minúsculas). El registro crea estudiantes salvo que llegue el código de profesor correcto (`codigoProfesor`, ver 4.2); los profesores también se crean con `npm run crear-profesor` (ver 8). La app abre la ventana del profesor cuando el rol es `profesor` o `admin`.

### 4.2 Registrar usuario

```http
POST /api/auth/register
Content-Type: application/json

{"username": "laura", "email": "laura@example.com", "password": "secreto123"}
```

- `username` y `email` se guardan en minúsculas y sin espacios alrededor. Si no llega `username`, se usa el correo.
- Validación: correo con formato válido y contraseña de al menos 8 caracteres. La app además exige usuario y correo no vacíos y comprueba la confirmación de contraseña en el cliente.
- `201 Created`: objeto usuario más `token`.
- `400 VALIDATION_ERROR`: datos inválidos. La app muestra `No se pudo crear la cuenta`.
- `409 DUPLICATE_USER`: el mensaje dice qué está repetido, `El correo ya está registrado` o `El nombre de usuario ya está en uso`. La app muestra ese mensaje.
- Profesores: opcional `"codigoProfesor"`. Si coincide con la variable `TEACHER_SIGNUP_CODE` del servidor la cuenta se crea con rol `profesor`; si no coincide (o el servidor no tiene código) `403 INVALID_TEACHER_CODE` "Código de profesor inválido" y no se crea nada. El rol nunca se elige directamente. En la app el campo aparece al tocar "¿Eres profesor?" en el registro.

### 4.3 Iniciar sesión

```http
POST /api/auth/login
Content-Type: application/json

{"username": "laura@example.com", "password": "secreto123"}
```

- `username` acepta el nombre de usuario o el correo (sin distinguir mayúsculas).
- `200 OK`: objeto usuario más `token`.
- `401 INVALID_CREDENTIALS`: la app muestra `Correo o contraseña incorrectos` para cualquier estado distinto de `200`.
- Un hash bcrypt antiguo se rehace con scrypt al iniciar sesión.

### 4.4 Sesión actual y cierre

```http
GET /api/auth/me
Authorization: Bearer <token>
```

`200 OK` con el objeto usuario. La app lo llama al arrancar (`SessionGate`) para restaurar la sesión; si responde `401` olvida el token y muestra el login, y si no hay conexión muestra "Sin conexión" con "Reintentar".

```http
POST /api/auth/logout
Authorization: Bearer <token>
```

`204 No Content`; el token deja de valer al instante. La app olvida el token aunque no haya conexión.

### 4.5 Preguntas diarias y semanales

```http
GET /api/preguntas/diarias
GET /api/preguntas/semanales
Authorization: Bearer <token>
```

`200 OK` con un array (5 diarias, 10 semanales), ordenado por `posicion`:

```json
[
  {
    "reto_id": 1,
    "posicion": 1,
    "id": 4,
    "tipo": "opcion_multiple",
    "enunciado": "Que estructura sigue el principio FIFO?",
    "puntos": 1,
    "realizada": false,
    "opciones": [
      {"id": 13, "texto": "Pila"},
      {"id": 14, "texto": "Cola"},
      {"id": 15, "texto": "Matriz"},
      {"id": 16, "texto": "Arbol"}
    ]
  }
]
```

- `realizada`: el usuario ya respondió esa pregunta en el periodo actual.
- El conjunto se elige al azar la primera vez que se pide en el día (o la semana, de lunes a domingo según `TZ`) entre las preguntas activas del reto activo de ese tipo, y queda fijo durante el periodo (`reto_diario_preguntas`, `reto_semanal_preguntas`).
- Nunca incluye `es_correcta`.
- Cualquier estado distinto de `200`: la app muestra `No se pudieron cargar los retos…` con "Reintentar".

### 4.6 Responder una pregunta

```http
POST /api/preguntas/diarias/:idPregunta/responder
POST /api/preguntas/semanales/:idPregunta/responder
Authorization: Bearer <token>
Content-Type: application/json

{"opcionId": 14, "tiempoSegundos": 4}
```

- `opcionId: null` registra tiempo agotado o abandono como fallo. La app lo envía al acabarse los 15 s o al salir del reto semanal con una pregunta en curso.
- `201 Created`:

```json
{
  "correcta": true,
  "puntos_ganados": 1,
  "puntos_bonus": 0,
  "puntos_totales": 13,
  "retos_completados": 5,
  "racha_actual": 2,
  "racha_maxima": 4,
  "reto_completado": false
}
```

- `reto_completado`: el intento del periodo ya tiene todas sus preguntas respondidas.
- `puntos_bonus`: solo es mayor que 0 en la respuesta que completa el reto diario. Vale `min(racha_actual, 10)` y ya está sumado en `puntos_totales` (y en el ranking).
- `racha_actual` / `racha_maxima`: como en el usuario; la app los copia a `AuthUser` igual que los puntos.
- Orden: las preguntas del periodo se responden por `posicion`. Si queda alguna anterior sin responder, devuelve `409 QUESTION_LOCKED` con `Responde antes el reto N` (N = la primera pendiente). Un tiempo agotado cuenta como respondido.
- Errores: `400 VALIDATION_ERROR` (id de pregunta inválido), `400 INVALID_OPTION` (la opción no es de esa pregunta), `404 QUESTION_NOT_FOUND` (la pregunta no está en el conjunto del periodo), `409 QUESTION_ALREADY_ANSWERED` (`Esta pregunta ya fue realizada hoy` / `esta semana`), `409 QUESTION_LOCKED`. La app muestra el mensaje de los `409` y `No se pudo guardar la respuesta` para los demás. Además bloquea en el camino los retos posteriores al siguiente pendiente, así que normalmente no llega a recibir `QUESTION_LOCKED`.

### 4.7 Clasificación

```http
GET /api/usuarios/ranking?limit=5
Authorization: Bearer <token>
```

- `limit` entre 1 y 50; por defecto 5. La app pide 5.
- Solo entran los usuarios con rol `ESTUDIANTE`; los profesores no aparecen.
- Orden: `puntos_totales` de mayor a menor y luego `username`. La posición es el orden de la lista (los empates no comparten puesto).

```json
[
  {"posicion": 1, "id": 3, "username": "maria_g", "puntos_totales": 34}
]
```

La app usa esta lista para la tabla de clasificación de Inicio.

```http
GET /api/usuarios/ranking/me
Authorization: Bearer <token>
```

`200 OK` con el puesto del usuario de la sesión en la clasificación completa, con la misma forma y el mismo orden que una fila del ranking, aunque quede fuera del `limit`:

```json
{"posicion": 8, "id": 7, "username": "laura", "puntos_totales": 12}
```

La app lo muestra en la barra superior de Inicio y en el perfil; si falla muestra "—". `404 USER_NOT_FOUND` si el usuario ya no existe o es profesor (no está en la clasificación).

### 4.8 Editar el perfil

```http
PATCH /api/usuarios/:id
Authorization: Bearer <token>
Content-Type: application/json

{"username": "laura_m", "password": "contraseña actual"}
```

- Se envía `username`, `email` o ambos, más la `password` actual. Se guardan en minúsculas; máximo 100 caracteres.
- `200 OK`: `{"id": 7, "username": "laura_m", "email": "laura@example.com"}`.
- Errores: `400 VALIDATION_ERROR`, `401 INVALID_CREDENTIALS` (contraseña incorrecta; no cierra la sesión), `403 FORBIDDEN` (el `:id` no es el de la sesión), `404 USER_NOT_FOUND`, `409 DUPLICATE_USER` (`El correo ya está registrado` o `El nombre de usuario ya está en uso`). La app muestra el mensaje del servidor dentro del diálogo.

### 4.9 Banco de preguntas (profesores)

Exigen sesión de un usuario con rol `PROFESOR` o `ADMIN`; con otro rol responden `403 FORBIDDEN` ("Solo para profesores").

Clasificación completa de 10 en 10 (Inicio del profesor en la app, con Anterior/Siguiente):

```http
GET /api/profesor/clasificacion?pagina=1
Authorization: Bearer <token>
```

- `200 OK`: `{"clasificacion": [{"posicion", "id", "username", "puntos_totales"}], "pagina": 1, "total": 11, "total_paginas": 2}`. Mismo orden y filas que `/api/usuarios/ranking` (solo `ESTUDIANTE`). `pagina` inválida = 1; una página fuera de rango devuelve la lista vacía.

```http
GET /api/profesor/preguntas?pagina=1
Authorization: Bearer <token>
```

`200 OK` con 5 preguntas por página (fijo), las más nuevas primero. Una página fuera de rango devuelve `preguntas: []` con el total correcto. A diferencia de las rutas de estudiante, incluye `es_correcta`:

```json
{
  "preguntas": [
    {"id": 20, "enunciado": "Que ordenamiento...", "puntos": 1, "activa": true,
     "opciones": [{"id": 77, "texto": "Quicksort", "es_correcta": true}]}
  ],
  "pagina": 1,
  "total": 20,
  "total_paginas": 4
}
```

```http
POST /api/profesor/preguntas
Authorization: Bearer <token>
Content-Type: application/json

{"enunciado": "¿Qué es una cola?", "opciones": ["LIFO", "FIFO", "Árbol", "Grafo"], "correcta": 1}
```

- Exactamente 4 opciones (texto de 1 a 200 caracteres, sin repetidas ignorando mayúsculas); enunciado de 1 a 500; `correcta` es el índice 0–3.
- Se guarda con 1 punto, dificultad `MEDIO` y el área del reto diario activo, y se añade a `reto_preguntas` de los retos `DIARIO` y `SEMANAL` activos (al final), así que entra en los sorteos de los días y semanas siguientes (los conjuntos ya elegidos no cambian).
- `201 Created` con la pregunta en la misma forma que una fila de la lista. `400 VALIDATION_ERROR` con el motivo; la app lo muestra en el formulario.

### 4.10 Retos personalizados

Un profesor crea un reto con preguntas del banco, cronómetro propio y una duración; el servidor genera un **código** de 6 caracteres (sin `0`, `O`, `1` ni `I`) que el estudiante escribe en Inicio. Se guarda en `retos` con `tipo = 'TIEMPO_DEFINIDO'`, `codigo`, `segundos_por_pregunta` y `da_puntos` (migración `004_retos_personalizados.sql`).

**Profesor** (rol `PROFESOR`/`ADMIN`):

```http
POST /api/profesor/retos
{"titulo": "Repaso de pilas", "preguntas": [5, 2, 9], "segundosPregunta": 20, "daPuntos": false, "duracionHoras": 24}
```

- `titulo` 1–150; `preguntas` 1–20 ids distintos de preguntas activas (se juegan en ese orden); `segundosPregunta` ∈ 10, 15, 20, 30, 45, 60; `daPuntos` booleano; `duracionHoras` ∈ 1, 2, 24, 72, 168 (desde ahora).
- `201` con el reto: `{"id", "titulo", "codigo", "cantidad_preguntas", "segundos_por_pregunta", "da_puntos", "fecha_inicio", "fecha_fin", "activo", "estudiantes"}` (fechas ISO con zona). `400 VALIDATION_ERROR` con el motivo.
- `GET /api/profesor/retos`: los retos del profesor (hasta 50, más nuevos primero) con esa forma. `estudiantes` = estudiantes que han respondido al menos una pregunta.
- `GET /api/profesor/retos/:id/estadisticas`: solo el creador (o un admin), si no `404 CHALLENGE_NOT_FOUND`.

```json
{"reto": {...}, "estudiantes": 2, "preguntas": [
  {"id": 5, "posicion": 1, "enunciado": "...", "sin_respuesta": 1, "estudiantes_sin_respuesta": ["marta"],
   "opciones": [{"id": 17, "texto": "Cola", "es_correcta": false, "respuestas": 1, "estudiantes": ["laura"]}]}
]}
```

`respuestas` = estudiantes que eligieron esa opción y `estudiantes` sus nombres de usuario (orden alfabético); `sin_respuesta` / `estudiantes_sin_respuesta` = se les acabó el tiempo o salieron. En la app, tocar el número de una opción abre una ventana con esos nombres.

**Estudiante**:

- `GET /api/retos-personalizados/:codigo` (sin distinguir mayúsculas): `{"id", "titulo", "segundos_por_pregunta", "da_puntos", "fecha_fin", "preguntas"}` con preguntas en la misma forma que las diarias (`realizada`, sin la respuesta correcta). `404 CHALLENGE_NOT_FOUND` "Código no válido"; `410 CHALLENGE_EXPIRED` "Este reto ya terminó".
- `POST /api/retos-personalizados/:codigo/preguntas/:idPregunta/responder`: igual que el diario (`opcionId`, `tiempoSegundos`) y misma respuesta (`puntos_bonus` siempre 0). En orden (`409 QUESTION_LOCKED` "Responde antes la pregunta N"), una vez (`409 QUESTION_ALREADY_ANSWERED`) y solo mientras está vigente (`410`). Un intento por estudiante y reto (`fecha_dia` = día de creación del reto).
- Si `da_puntos` es falso, `puntos_ganados` es 0 y esas respuestas no cuentan ni en puntos ni en `retos_completados`.

### 4.11 Estado del servicio

```http
GET /health
```

`200 {"status": "ok", "database": "ok"}`, o `503 {"status": "ok", "database": "unavailable"}` si PostgreSQL no responde. No requiere token.

## 5. Autenticación

- Tokens de sesión opacos: 32 bytes aleatorios en base64url (43 caracteres). En la tabla `sesiones` solo se guarda su SHA-256.
- Caducan tras 30 días sin uso; cada petición autenticada renueva el plazo, como mucho una vez al día.
- Sin token, con formato inválido o con una sesión caducada o cerrada: `401` con código `UNAUTHORIZED`. La app borra el token y vuelve al login. Otros `401` (`INVALID_CREDENTIALS`) no cierran la sesión.
- La app guarda el token con `flutter_secure_storage` (clave `session_token`, `lib/api/session_store.dart`).
- Contraseñas con `crypto.scrypt` (`scrypt$N$r$p$salt$hash`); `bcryptjs` solo verifica hashes antiguos.

## 6. Errores

Todas las respuestas de error tienen la misma forma:

```json
{"error": {"code": "VALIDATION_ERROR", "message": "Correo y contraseña inválidos"}}
```

| Estado | Códigos |
| --- | --- |
| `400` | `VALIDATION_ERROR`, `INVALID_OPTION`, `INVALID_JSON` |
| `401` | `UNAUTHORIZED`, `INVALID_CREDENTIALS` |
| `403` | `FORBIDDEN` |
| `404` | `NOT_FOUND` (ruta inexistente), `QUESTION_NOT_FOUND`, `USER_NOT_FOUND` |
| `409` | `DUPLICATE_USER`, `QUESTION_ALREADY_ANSWERED`, `QUESTION_LOCKED` |
| `413` | `PAYLOAD_TOO_LARGE` |
| `500` | `INTERNAL_ERROR` (el detalle solo va al log del servidor) |

## 7. Reglas de negocio

- Las preguntas de un periodo se responden en orden de `posicion` (diarias y semanales); el backend lo exige con `409 QUESTION_LOCKED`.
- Cada pregunta tiene 15 s en la app (en los retos personalizados, lo que elija el profesor); sin respuesta cuenta como incorrecta y queda realizada en ese periodo.
- Una respuesta por usuario, pregunta y periodo (`respuestas_estudiante`, único por intento y pregunta).
- Un intento por usuario, reto y periodo (`intentos.fecha_dia`; en el semanal es el lunes). Pasa a `COMPLETADO` al responder `retos.cantidad_preguntas` preguntas.
- Puntos = suma de `preguntas.puntos` de las respuestas correctas de retos con `da_puntos` + bonus de racha; `respuestas_estudiante` es la fuente de verdad. `retos_completados` cuenta las respuestas de esos mismos retos. El cálculo está en `src/utils/progress.js`. `intentos.puntaje_total` se actualiza pero no se usa para los puntos.
- El reto semanal se juega seguido en la app, pero cada respuesta se guarda al momento: salir equivale a pausar.

## 8. Base de datos

- PostgreSQL 17 en Docker (`docker compose up -d postgres`, contenedor `questionsapp-pg`, puerto `5432`).
- Crear un profesor (o convertir una cuenta existente): `npm run crear-profesor -- <usuario> <correo> <contraseña>`. En la base local de desarrollo ya existe `profesor` / `profesor123` (`profesor@questionsapp.com`).
- `database/schema.sql` y `database/seed.sql` se ejecutan con el volumen vacío. El seed trae 1 área, 2 retos activos (diario de 5 y semanal de 10) y 20 preguntas con 80 opciones; no trae usuarios.
- Bases ya creadas: migraciones idempotentes `database/migrations/001_reto_semanal.sql` a `004_retos_personalizados.sql` en orden, y recargar `database/seed.sql`.

## 9. Pruebas rápidas sin abrir Flutter

Con el backend en `http://localhost:8080`:

```bash
# Registro: devuelve el token
curl -i -X POST http://localhost:8080/api/auth/register \
  -H 'Content-Type: application/json' \
  -d '{"username":"nueva","email":"nueva@example.com","password":"secreto123"}'

# Login con usuario o correo
curl -i -X POST http://localhost:8080/api/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"nueva@example.com","password":"secreto123"}'

# Rutas protegidas
TOKEN=<token>
curl -i http://localhost:8080/api/auth/me -H "Authorization: Bearer $TOKEN"
curl -i http://localhost:8080/api/preguntas/diarias -H "Authorization: Bearer $TOKEN"
curl -i http://localhost:8080/api/preguntas/semanales -H "Authorization: Bearer $TOKEN"
curl -i 'http://localhost:8080/api/usuarios/ranking?limit=5' -H "Authorization: Bearer $TOKEN"
curl -i http://localhost:8080/api/usuarios/ranking/me -H "Authorization: Bearer $TOKEN"
curl -i -X POST http://localhost:8080/api/preguntas/diarias/4/responder \
  -H "Authorization: Bearer $TOKEN" -H 'Content-Type: application/json' \
  -d '{"opcionId":14,"tiempoSegundos":4}'

# Profesor: banco de preguntas y alta
curl -i 'http://localhost:8080/api/profesor/preguntas?pagina=1' -H "Authorization: Bearer $TOKEN_PROFESOR"
curl -i -X POST http://localhost:8080/api/profesor/preguntas \
  -H "Authorization: Bearer $TOKEN_PROFESOR" -H 'Content-Type: application/json' \
  -d '{"enunciado":"¿Qué es una cola?","opciones":["LIFO","FIFO","Árbol","Grafo"],"correcta":1}'

curl -i http://localhost:8080/health
```

## 10. Referencia del cliente Flutter

- Cliente HTTP: `lib/api/api_client.dart` (`ApiClient`, global `apiClient`); modelos en `lib/api/models.dart`.
- Dependencia HTTP: `http`. URL configurable con `API_BASE_URL` mediante `--dart-define`.
- No hay secretos ni credenciales del backend en el proyecto Flutter.

## 11. Pendiente

- Límite de intentos en login y registro.
- Build de release en Android: el manifest principal no declara el permiso `INTERNET` ni permite HTTP sin cifrar, así que un APK de release no podría hablar con un backend `http://`.
