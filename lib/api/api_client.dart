import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'session_store.dart';

class ApiClient {
  ApiClient({http.Client? client, this._store = sessionStore}) : _client = client ?? http.Client();
  final http.Client _client;
  final SessionStore _store;

  String get baseUrl => const String.fromEnvironment('API_BASE_URL', defaultValue: 'http://127.0.0.1:8080');

  /// Token de la sesión actual; viaja en `Authorization` en cada petición.
  String? token;

  /// Se llama cuando el servidor rechaza la sesión (caducada o cerrada en otro sitio).
  void Function()? onSessionExpired;

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  Future<http.Response> _get(String path) => _guard(_client.get(Uri.parse('$baseUrl$path'), headers: _headers));

  Future<http.Response> _post(String path, Map<String, Object?> body) =>
      _guard(_client.post(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));

  Future<http.Response> _patch(String path, Map<String, Object?> body) =>
      _guard(_client.patch(Uri.parse('$baseUrl$path'), headers: _headers, body: jsonEncode(body)));

  /// Un 401 `UNAUTHORIZED` es sesión no válida. Otros 401, como una contraseña
  /// incorrecta al editar el perfil, los trata cada llamada.
  Future<http.Response> _guard(Future<http.Response> request) async {
    final response = await request;
    if (response.statusCode == 401 && _errorCode(response) == 'UNAUTHORIZED') {
      await _forget();
      onSessionExpired?.call();
      throw const SessionExpiredException();
    }
    return response;
  }

  Future<AuthUser> login(String username, String password) async {
    final response = await _post('/api/auth/login', {'username': username, 'password': password});
    if (response.statusCode != 200) throw ApiException('Correo o contraseña incorrectos');
    return _startSession(response);
  }

  /// Con `teacherCode` (el código secreto del servidor) la cuenta se crea como profesor.
  Future<AuthUser> register(String username, String email, String password, {String? teacherCode}) async {
    final response = await _post('/api/auth/register', {
      'username': username,
      'email': email,
      'password': password,
      'codigoProfesor': ?teacherCode,
    });
    // El servidor dice si lo repetido es el correo o el nombre de usuario.
    if (response.statusCode == 409) throw ApiException(_errorMessage(response, 'El correo o el nombre de usuario ya están en uso'));
    if (response.statusCode == 403) throw ApiException(_errorMessage(response, 'Código de profesor inválido'));
    if (response.statusCode != 201) throw ApiException('No se pudo crear la cuenta');
    return _startSession(response);
  }

  Future<AuthUser> _startSession(http.Response response) async {
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    token = json['token'] as String;
    await _store.save(token!);
    return AuthUser.fromJson(json);
  }

  /// Recupera la sesión guardada al abrir la app. Devuelve null si no hay sesión
  /// o el servidor ya no la acepta; lanza [ApiException] si no hay conexión.
  Future<AuthUser?> restoreSession() async {
    token = await _store.read();
    if (token == null) return null;
    final http.Response response;
    try {
      response = await _client.get(Uri.parse('$baseUrl/api/auth/me'), headers: _headers);
    } catch (_) {
      throw const ApiException('No se pudo conectar con el servidor. Comprueba tu conexión.');
    }
    if (response.statusCode == 401) {
      await _forget();
      return null;
    }
    if (response.statusCode != 200) throw const ApiException('No se pudo recuperar la sesión');
    return AuthUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Cierra la sesión en el servidor si se puede y siempre la olvida en el dispositivo.
  Future<void> logout() async {
    if (token != null) {
      try {
        await _client.post(Uri.parse('$baseUrl/api/auth/logout'), headers: _headers);
      } catch (_) {
        // Sin conexión: el token caducará solo en el servidor.
      }
    }
    await _forget();
  }

  Future<void> _forget() async {
    token = null;
    await _store.clear();
  }

  Future<List<Question>> dailyQuestions() => _questions('diarias');

  Future<List<Question>> weeklyQuestions() => _questions('semanales');

  Future<AnswerResult> answerDailyQuestion({required int questionId, int? optionId, required int elapsedSeconds}) =>
      _answer('diarias', questionId: questionId, optionId: optionId, elapsedSeconds: elapsedSeconds);

  Future<AnswerResult> answerWeeklyQuestion({required int questionId, int? optionId, required int elapsedSeconds}) =>
      _answer('semanales', questionId: questionId, optionId: optionId, elapsedSeconds: elapsedSeconds);

  /// [kind] es el segmento de la ruta del reto: `diarias` o `semanales`.
  Future<List<Question>> _questions(String kind) async {
    final response = await _get('/api/preguntas/$kind');
    if (response.statusCode != 200) throw ApiException('No se pudieron cargar las preguntas');
    return (jsonDecode(response.body) as List)
        .map((item) => Question.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<AnswerResult> _answer(String kind, {required int questionId, int? optionId, required int elapsedSeconds}) async {
    final response = await _post('/api/preguntas/$kind/$questionId/responder', {'opcionId': optionId, 'tiempoSegundos': elapsedSeconds});
    // 409: pregunta ya respondida o bloqueada por retos anteriores pendientes.
    if (response.statusCode == 409) throw ApiException(_errorMessage(response, 'Esta pregunta no se puede responder ahora'));
    if (response.statusCode != 201) throw ApiException('No se pudo guardar la respuesta');
    return AnswerResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AuthUser> updateProfile({required AuthUser user, String? username, String? email, required String password}) async {
    final response = await _patch('/api/usuarios/${user.id}', {'username': ?username, 'email': ?email, 'password': password});
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudo actualizar el perfil'));
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return user.copyWith(username: json['username'] as String, email: json['email'] as String);
  }

  String? _errorCode(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['error']['code'] as String;
    } catch (_) {
      return null;
    }
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['error']['message'] as String;
    } catch (_) {
      return fallback;
    }
  }

  Future<List<RankingEntry>> ranking() async {
    final response = await _get('/api/usuarios/ranking?limit=5');
    if (response.statusCode != 200) throw ApiException('No se pudo cargar la clasificación');
    return (jsonDecode(response.body) as List)
        .map((item) => RankingEntry.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Puesto del usuario de la sesión en la clasificación completa.
  Future<RankingEntry> myRanking() async {
    final response = await _get('/api/usuarios/ranking/me');
    if (response.statusCode != 200) throw ApiException('No se pudo cargar tu puesto');
    return RankingEntry.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Clasificación completa para profesores, de 10 en 10; `page` empieza en 1.
  Future<RankingPage> rankingPage({required int page}) async {
    final response = await _get('/api/profesor/clasificacion?pagina=$page');
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudo cargar la clasificación'));
    return RankingPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Banco de preguntas para profesores, de 5 en 5; `page` empieza en 1.
  Future<QuestionPage> questionBank({required int page}) async {
    final response = await _get('/api/profesor/preguntas?pagina=$page');
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudieron cargar las preguntas'));
    return QuestionPage.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Crea una pregunta de 4 opciones; `correct` es el índice de la correcta.
  Future<BankQuestion> createQuestion({required String text, required List<String> options, required int correct}) async {
    final response = await _post('/api/profesor/preguntas', {'enunciado': text, 'opciones': options, 'correcta': correct});
    if (response.statusCode != 201) throw ApiException(_errorMessage(response, 'No se pudo guardar la pregunta'));
    return BankQuestion.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Retos personalizados del profesor de la sesión, los más nuevos primero.
  Future<List<CustomChallenge>> customChallenges() async {
    final response = await _get('/api/profesor/retos');
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudieron cargar los retos'));
    return (jsonDecode(response.body) as List)
        .map((item) => CustomChallenge.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  /// Crea un reto personalizado; el servidor genera su código.
  Future<CustomChallenge> createCustomChallenge({required String title, required List<int> questionIds, required int secondsPerQuestion, required bool givesPoints, required int durationHours}) async {
    final response = await _post('/api/profesor/retos', {
      'titulo': title,
      'preguntas': questionIds,
      'segundosPregunta': secondsPerQuestion,
      'daPuntos': givesPoints,
      'duracionHoras': durationHours,
    });
    if (response.statusCode != 201) throw ApiException(_errorMessage(response, 'No se pudo crear el reto'));
    return CustomChallenge.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Cuántos estudiantes eligieron cada opción de cada pregunta del reto.
  Future<ChallengeStats> customChallengeStats(int challengeId) async {
    final response = await _get('/api/profesor/retos/$challengeId/estadisticas');
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudieron cargar los resultados'));
    return ChallengeStats.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  /// Reto personalizado con el código que da el profesor (sin distinguir mayúsculas).
  Future<CustomChallengeRun> joinCustomChallenge(String code) async {
    final normalized = code.trim().toUpperCase();
    final response = await _get('/api/retos-personalizados/${Uri.encodeComponent(normalized)}');
    if (response.statusCode != 200) throw ApiException(_errorMessage(response, 'No se pudo abrir el reto'));
    return CustomChallengeRun.fromJson(normalized, jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<AnswerResult> answerCustomQuestion({required String code, required int questionId, int? optionId, required int elapsedSeconds}) async {
    final response = await _post('/api/retos-personalizados/$code/preguntas/$questionId/responder', {'opcionId': optionId, 'tiempoSegundos': elapsedSeconds});
    // 409 (bloqueada o ya respondida) y 410 (reto terminado) traen un mensaje para el estudiante.
    if (response.statusCode == 409 || response.statusCode == 410) throw ApiException(_errorMessage(response, 'Esta pregunta no se puede responder ahora'));
    if (response.statusCode != 201) throw ApiException('No se pudo guardar la respuesta');
    return AnswerResult.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }
}

class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
}

class SessionExpiredException extends ApiException {
  const SessionExpiredException() : super('Tu sesión ha caducado. Vuelve a iniciar sesión.');
}

final apiClient = ApiClient();
