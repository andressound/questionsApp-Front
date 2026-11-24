class AuthUser {
  const AuthUser({required this.id, required this.username, required this.email, required this.points, required this.completedChallenges, required this.role, this.streak = 0, this.bestStreak = 0});
  final int id;
  final String username;
  final String email;
  final int points;
  final int completedChallenges;
  /// `estudiante`, `profesor` o `admin`.
  final String role;

  /// Los profesores (y administradores) entran a la ventana del banco de preguntas.
  bool get isTeacher => role == 'profesor' || role == 'admin';

  /// Días seguidos con el reto diario completado; sigue viva si el último fue hoy o ayer.
  final int streak;
  final int bestStreak;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
        id: (json['id'] as num).toInt(),
        username: json['username'] as String,
        email: json['email'] as String? ?? '',
        points: (json['puntos_totales'] as num?)?.toInt() ?? 0,
        completedChallenges: (json['retos_completados'] as num?)?.toInt() ?? 0,
        role: json['rol'] as String,
        streak: (json['racha_actual'] as num?)?.toInt() ?? 0,
        bestStreak: (json['racha_maxima'] as num?)?.toInt() ?? 0,
      );

  AuthUser copyWith({String? username, String? email, int? points, int? completedChallenges, int? streak, int? bestStreak}) => AuthUser(
        id: id,
        username: username ?? this.username,
        email: email ?? this.email,
        points: points ?? this.points,
        completedChallenges: completedChallenges ?? this.completedChallenges,
        role: role,
        streak: streak ?? this.streak,
        bestStreak: bestStreak ?? this.bestStreak,
      );

  String get initials => initialsOf(username);
}

/// Hasta dos iniciales a partir del nombre de usuario, para el avatar.
String initialsOf(String username) {
  final parts = username.trim().split(RegExp(r'[\s._-]+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

class AnswerResult {
  const AnswerResult({required this.correct, required this.points, required this.completedChallenges, this.streak = 0, this.bestStreak = 0, this.streakBonus = 0});
  final bool correct;
  final int points;
  final int completedChallenges;
  final int streak;
  final int bestStreak;

  /// Puntos extra por racha; solo llegan con la respuesta que completa el reto diario.
  final int streakBonus;

  factory AnswerResult.fromJson(Map<String, dynamic> json) => AnswerResult(
        correct: json['correcta'] == true,
        points: (json['puntos_totales'] as num?)?.toInt() ?? 0,
        completedChallenges: (json['retos_completados'] as num?)?.toInt() ?? 0,
        streak: (json['racha_actual'] as num?)?.toInt() ?? 0,
        bestStreak: (json['racha_maxima'] as num?)?.toInt() ?? 0,
        streakBonus: (json['puntos_bonus'] as num?)?.toInt() ?? 0,
      );
}

class Question {
  const Question({required this.id, required this.position, required this.type, required this.text, required this.points, required this.options, required this.completed});
  final int id;
  final int position;
  final String type;
  final String text;
  final int points;
  final List<QuestionOption> options;
  final bool completed;

  factory Question.fromJson(Map<String, dynamic> json) => Question(
        id: (json['id'] as num).toInt(),
        position: (json['posicion'] as num?)?.toInt() ?? 1,
        type: json['tipo'] as String,
        text: json['enunciado'] as String,
        points: (json['puntos'] as num?)?.toInt() ?? 1,
        options: (json['opciones'] as List)
            .map((item) => QuestionOption.fromJson(item as Map<String, dynamic>))
            .toList(),
        completed: json['realizada'] == true || json['realizada'] == 1,
      );
}

class QuestionOption {
  const QuestionOption({required this.id, required this.text});
  final int id;
  final String text;

  factory QuestionOption.fromJson(Map<String, dynamic> json) => QuestionOption(
        id: (json['id'] as num).toInt(),
        text: json['texto'] as String,
      );
}

class RankingEntry {
  const RankingEntry({required this.position, required this.id, required this.username, required this.points});
  final int position;
  final int id;
  final String username;
  final int points;

  factory RankingEntry.fromJson(Map<String, dynamic> json) => RankingEntry(
        position: (json['posicion'] as num).toInt(),
        id: (json['id'] as num).toInt(),
        username: json['username'] as String,
        points: (json['puntos_totales'] as num).toInt(),
      );
}

/// Una página de la clasificación completa (10 estudiantes) para el profesor.
class RankingPage {
  const RankingPage({required this.entries, required this.page, required this.total, required this.totalPages});
  final List<RankingEntry> entries;
  final int page;
  final int total;
  final int totalPages;

  factory RankingPage.fromJson(Map<String, dynamic> json) => RankingPage(
        entries: (json['clasificacion'] as List)
            .map((item) => RankingEntry.fromJson(item as Map<String, dynamic>))
            .toList(),
        page: (json['pagina'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        totalPages: (json['total_paginas'] as num).toInt(),
      );
}

/// Pregunta del banco tal como la ve un profesor: con la opción correcta marcada.
class BankQuestion {
  const BankQuestion({required this.id, required this.text, required this.options});
  final int id;
  final String text;
  final List<BankOption> options;

  BankOption? get correctOption {
    for (final option in options) {
      if (option.isCorrect) return option;
    }
    return null;
  }

  factory BankQuestion.fromJson(Map<String, dynamic> json) => BankQuestion(
        id: (json['id'] as num).toInt(),
        text: json['enunciado'] as String,
        options: (json['opciones'] as List)
            .map((item) => BankOption.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class BankOption {
  const BankOption({required this.id, required this.text, required this.isCorrect});
  final int id;
  final String text;
  final bool isCorrect;

  factory BankOption.fromJson(Map<String, dynamic> json) => BankOption(
        id: (json['id'] as num).toInt(),
        text: json['texto'] as String,
        isCorrect: json['es_correcta'] == true,
      );
}

/// Una página del banco de preguntas (5 por página).
class QuestionPage {
  const QuestionPage({required this.questions, required this.page, required this.total, required this.totalPages});
  final List<BankQuestion> questions;
  final int page;
  final int total;
  final int totalPages;

  factory QuestionPage.fromJson(Map<String, dynamic> json) => QuestionPage(
        questions: (json['preguntas'] as List)
            .map((item) => BankQuestion.fromJson(item as Map<String, dynamic>))
            .toList(),
        page: (json['pagina'] as num).toInt(),
        total: (json['total'] as num).toInt(),
        totalPages: (json['total_paginas'] as num).toInt(),
      );
}

/// Reto personalizado tal como lo ve el profesor que lo creó.
class CustomChallenge {
  const CustomChallenge({required this.id, required this.title, required this.code, required this.questionCount, required this.secondsPerQuestion, required this.givesPoints, required this.endsAt, required this.active, required this.students});
  final int id;
  final String title;
  final String code;
  final int questionCount;
  final int secondsPerQuestion;
  final bool givesPoints;
  final DateTime endsAt;
  final bool active;

  /// Estudiantes que han respondido al menos una pregunta.
  final int students;

  factory CustomChallenge.fromJson(Map<String, dynamic> json) => CustomChallenge(
        id: (json['id'] as num).toInt(),
        title: json['titulo'] as String,
        code: json['codigo'] as String,
        questionCount: (json['cantidad_preguntas'] as num).toInt(),
        secondsPerQuestion: (json['segundos_por_pregunta'] as num).toInt(),
        givesPoints: json['da_puntos'] == true,
        endsAt: DateTime.parse(json['fecha_fin'] as String).toLocal(),
        active: json['activo'] == true,
        students: (json['estudiantes'] as num?)?.toInt() ?? 0,
      );
}

/// Reto personalizado al que entra un estudiante con su código.
class CustomChallengeRun {
  const CustomChallengeRun({required this.code, required this.title, required this.secondsPerQuestion, required this.givesPoints, required this.endsAt, required this.questions});
  final String code;
  final String title;
  final int secondsPerQuestion;
  final bool givesPoints;
  final DateTime endsAt;
  final List<Question> questions;

  factory CustomChallengeRun.fromJson(String code, Map<String, dynamic> json) => CustomChallengeRun(
        code: code,
        title: json['titulo'] as String,
        secondsPerQuestion: (json['segundos_por_pregunta'] as num).toInt(),
        givesPoints: json['da_puntos'] == true,
        endsAt: DateTime.parse(json['fecha_fin'] as String).toLocal(),
        questions: (json['preguntas'] as List)
            .map((item) => Question.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

/// Respuestas de los estudiantes a un reto personalizado, pregunta a pregunta.
class ChallengeStats {
  const ChallengeStats({required this.challenge, required this.students, required this.questions});
  final CustomChallenge challenge;
  final int students;
  final List<QuestionStats> questions;

  factory ChallengeStats.fromJson(Map<String, dynamic> json) => ChallengeStats(
        challenge: CustomChallenge.fromJson(json['reto'] as Map<String, dynamic>),
        students: (json['estudiantes'] as num).toInt(),
        questions: (json['preguntas'] as List)
            .map((item) => QuestionStats.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class QuestionStats {
  const QuestionStats({required this.id, required this.position, required this.text, required this.timedOut, this.timedOutStudents = const [], required this.options});
  final int id;
  final int position;
  final String text;

  /// Estudiantes a los que se les acabó el tiempo (o salieron) sin elegir opción.
  final int timedOut;

  /// Nombres de usuario de esos estudiantes.
  final List<String> timedOutStudents;
  final List<OptionStats> options;

  int get answers => timedOut + options.fold(0, (sum, option) => sum + option.count);

  factory QuestionStats.fromJson(Map<String, dynamic> json) => QuestionStats(
        id: (json['id'] as num).toInt(),
        position: (json['posicion'] as num).toInt(),
        text: json['enunciado'] as String,
        timedOut: (json['sin_respuesta'] as num?)?.toInt() ?? 0,
        timedOutStudents: _names(json['estudiantes_sin_respuesta']),
        options: (json['opciones'] as List)
            .map((item) => OptionStats.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
}

class OptionStats {
  const OptionStats({required this.id, required this.text, required this.isCorrect, required this.count, this.students = const []});
  final int id;
  final String text;
  final bool isCorrect;

  /// Estudiantes que eligieron esta opción.
  final int count;

  /// Nombres de usuario de esos estudiantes, en orden alfabético.
  final List<String> students;

  factory OptionStats.fromJson(Map<String, dynamic> json) => OptionStats(
        id: (json['id'] as num).toInt(),
        text: json['texto'] as String,
        isCorrect: json['es_correcta'] == true,
        count: (json['respuestas'] as num?)?.toInt() ?? 0,
        students: _names(json['estudiantes']),
      );
}

List<String> _names(Object? value) => value is List ? value.whereType<String>().toList() : const [];
