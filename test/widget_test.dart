// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/api/api_client.dart';
import 'package:flutter_application_1/api/session_store.dart';

import 'package:flutter_application_1/api/models.dart';
import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/app_shell.dart';
import 'package:flutter_application_1/screens/challenge_stats_screen.dart';
import 'package:flutter_application_1/screens/challenges_screen.dart';
import 'package:flutter_application_1/screens/new_challenge_screen.dart';
import 'package:flutter_application_1/screens/new_question_screen.dart';
import 'package:flutter_application_1/screens/quiz_screen.dart';
import 'package:flutter_application_1/screens/register_screen.dart';
import 'package:flutter_application_1/screens/teacher_shell.dart';
import 'package:flutter_application_1/screens/weekly_run_screen.dart';
import 'package:flutter_application_1/theme/app_theme.dart';
import 'package:flutter_application_1/widgets/common.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('navigates through auth screens', (tester) async {
    await tester.pumpWidget(const MyApp());
    // Sin sesión guardada, SessionGate lleva al login.
    await tester.pumpAndSettle();
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
    final registerLink = find.text('Regístrate');
    expect(registerLink, findsOneWidget);

    await tester.ensureVisible(registerLink);
    await tester.pumpAndSettle();
    await tester.tap(registerLink);
    await tester.pumpAndSettle();
    expect(find.text('Crea tu cuenta'), findsOneWidget);
    expect(find.text('CREAR CUENTA'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('INICIAR SESIÓN'), findsOneWidget);
  });

  testWidgets('navigates through app sections', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const AppShell(user: AuthUser(id: 1, username: 'Test User', email: 'test@example.com', points: 1250, completedChallenges: 3, role: 'estudiante')),
    ));
    await tester.pumpAndSettle();
    expect(find.text('RETOS DE HOY'), findsOneWidget);
    expect(find.text('Reto de tu profesor'), findsOneWidget);
    // La tarjeta del código la empuja hacia abajo; el primer Scrollable es la lista de Inicio.
    await tester.scrollUntilVisible(find.text('Clasificación'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Clasificación'), findsOneWidget);
    expect(find.text('TU'), findsOneWidget);

    await tester.tap(find.byTooltip('Retos'));
    await tester.pumpAndSettle();
    expect(find.byType(ChallengesScreen), findsOneWidget);
  });

  testWidgets('plays the pending weekly questions in a row and shows a summary', (tester) async {
    const user = AuthUser(id: 1, username: 'Test User', email: 'test@example.com', points: 0, completedChallenges: 0, role: 'estudiante');
    Question question(int position, {bool completed = false}) => Question(
          id: position,
          position: position,
          type: 'opcion_multiple',
          text: 'Pregunta $position',
          points: 2,
          options: [QuestionOption(id: position * 10, text: 'Opción $position')],
          completed: completed,
        );
    final submitted = <int>[];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: WeeklyRunScreen(
        user: user,
        questions: [question(1, completed: true), question(2), question(3)],
        submit: (question, optionId, elapsedSeconds) async {
          submitted.add(question.id);
          // Acierta la primera pendiente y falla la segunda.
          return AnswerResult(correct: question.id == 2, points: 2, completedChallenges: submitted.length + 1);
        },
      ),
    ));

    // La ya realizada se salta: empieza por la 2.ª de 3.
    expect(find.text('Pregunta 2/3'), findsOneWidget);
    await tester.tap(find.text('Opción 2'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Pregunta 3/3'), findsOneWidget);
    await tester.tap(find.text('Opción 3'));
    await tester.pump(const Duration(milliseconds: 1500));
    await tester.pump();

    expect(submitted, [2, 3]);
    expect(find.text('¡Reto semanal completado!'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
  });

  testWidgets('daily challenges unlock in order', (tester) async {
    Question question(int position, {bool completed = false}) => Question(
          id: position, position: position, type: 'opcion_multiple', text: 'Pregunta $position', points: 1, options: const [], completed: completed);
    final played = <int>[];

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChallengeTrail(questions: [question(1, completed: true), question(2), question(3)], initials: 'TU', onPlay: (q) => played.add(q.id)),
        ),
      ),
    ));

    // El 3 sigue bloqueado mientras falte el 2.
    await tester.tap(find.text('3'));
    await tester.pump();
    expect(played, isEmpty);
    expect(find.text('Bloqueado. Responde antes el reto 2.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    expect(played, [2]);
  });

  group('session', () {
    const userJson = {'id': 7, 'username': 'laura', 'email': 'laura@example.com', 'puntos_totales': 12, 'retos_completados': 4, 'racha_actual': 3, 'racha_maxima': 8, 'rol': 'estudiante'};

    test('restores a saved session with the stored token', () async {
      FlutterSecureStorage.setMockInitialValues({'session_token': 'token-guardado'});
      final client = ApiClient(client: MockClient((request) async {
        expect(request.url.path, '/api/auth/me');
        expect(request.headers['Authorization'], 'Bearer token-guardado');
        return http.Response(jsonEncode(userJson), 200);
      }));

      final user = await client.restoreSession();
      expect(user?.username, 'laura');
      expect(user?.points, 12);
      expect(user?.streak, 3);
      expect(user?.bestStreak, 8);
    });

    test('forgets a session the server rejects', () async {
      FlutterSecureStorage.setMockInitialValues({'session_token': 'caducado'});
      final client = ApiClient(client: MockClient((_) async => http.Response('{"error":{"code":"UNAUTHORIZED","message":"x"}}', 401)));

      expect(await client.restoreSession(), isNull);
      expect(client.token, isNull);
      expect(await sessionStore.read(), isNull);
    });

    test('saves the token on login and sends it afterwards', () async {
      final client = ApiClient(client: MockClient((request) async {
        if (request.url.path == '/api/auth/login') return http.Response(jsonEncode({...userJson, 'token': 'nuevo-token'}), 200);
        expect(request.headers['Authorization'], 'Bearer nuevo-token');
        return http.Response('[]', 200);
      }));

      await client.login('laura', 'secreto123');
      expect(await sessionStore.read(), 'nuevo-token');
      expect(await client.dailyQuestions(), isEmpty);
    });

    test('an expired session clears the token and notifies the app', () async {
      FlutterSecureStorage.setMockInitialValues({'session_token': 'viejo'});
      var expired = false;
      final client = ApiClient(client: MockClient((_) async => http.Response('{"error":{"code":"UNAUTHORIZED","message":"x"}}', 401)))
        ..token = 'viejo'
        ..onSessionExpired = () => expired = true;

      await expectLater(client.weeklyQuestions(), throwsA(isA<SessionExpiredException>()));
      expect(expired, isTrue);
      expect(await sessionStore.read(), isNull);
    });

    test('a wrong password on profile edit does not end the session', () async {
      var expired = false;
      final client = ApiClient(client: MockClient((_) async => http.Response('{"error":{"code":"INVALID_CREDENTIALS","message":"Contraseña incorrecta"}}', 401)))
        ..token = 'vigente'
        ..onSessionExpired = () => expired = true;
      const user = AuthUser(id: 7, username: 'laura', email: 'laura@example.com', points: 0, completedChallenges: 0, role: 'estudiante');

      await expectLater(client.updateProfile(user: user, username: 'otra', password: 'mala'), throwsA(isA<ApiException>()));
      expect(expired, isFalse);
      expect(client.token, 'vigente');
    });
  });

  test('streak fields default to zero when the server omits them', () {
    final user = AuthUser.fromJson({'id': 1, 'username': 'laura', 'email': '', 'rol': 'estudiante'});
    expect((user.streak, user.bestStreak), (0, 0));
    final result = AnswerResult.fromJson({'correcta': true, 'puntos_totales': 5});
    expect((result.streak, result.bestStreak, result.streakBonus), (0, 0, 0));
    final completed = AnswerResult.fromJson({'correcta': true, 'puntos_totales': 9, 'racha_actual': 4, 'racha_maxima': 6, 'puntos_bonus': 4});
    expect((completed.streak, completed.bestStreak, completed.streakBonus), (4, 6, 4));
  });

  testWidgets('profile shows the current and best streak', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: const AppShell(user: AuthUser(id: 1, username: 'Test User', email: 'test@example.com', points: 10, completedChallenges: 5, role: 'estudiante', streak: 4, bestStreak: 9)),
    ));
    await tester.tap(find.byTooltip('Perfil'));
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((widget) => widget is StatFigure && widget.label == 'Racha' && widget.value == '4'), findsOneWidget);
    expect(find.text('Mejor racha: 9 días'), findsOneWidget);
  });

  testWidgets('completing the daily challenge shows the streak bonus', (tester) async {
    AnswerResult? done;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: QuestionPlayer(
          question: const Question(id: 5, position: 5, type: 'opcion_multiple', text: 'Última', points: 1, options: [QuestionOption(id: 50, text: 'Opción A')], completed: false),
          submit: (optionId, elapsedSeconds) async =>
              const AnswerResult(correct: true, points: 9, completedChallenges: 5, streak: 3, bestStreak: 3, streakBonus: 3),
          onDone: (result) => done = result,
          onClose: (_) {},
        ),
      ),
    ));
    await tester.tap(find.text('Opción A'));
    await tester.pump();
    expect(find.text('Racha de 3 días · +3 puntos de bonus'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(done?.streakBonus, 3);
  });

  test('builds initials from the username', () {
    AuthUser user(String name) => AuthUser(id: 1, username: name, email: '', points: 0, completedChallenges: 0, role: 'estudiante');
    expect(user('Test User').initials, 'TU');
    expect(user('andres_munoz').initials, 'AM');
    expect(user('laura').initials, 'LA');
    expect(user('x').initials, 'X');
  });

  group('teacher signup', () {
    test('sends the teacher code only when there is one', () async {
      final bodies = <Map<String, dynamic>>[];
      final client = ApiClient(client: MockClient((request) async {
        expect(request.url.path, '/api/auth/register');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        bodies.add(body);
        if (body['codigoProfesor'] == 'malo') {
          return http.Response(jsonEncode({'error': {'code': 'INVALID_TEACHER_CODE', 'message': 'Código de profesor inválido'}}), 403);
        }
        return http.Response(jsonEncode({'id': 30, 'username': 'ana', 'email': 'ana@correo.com', 'rol': body.containsKey('codigoProfesor') ? 'profesor' : 'estudiante', 'token': 'x' * 43}), 201);
      }));

      expect((await client.register('ana', 'ana@correo.com', 'password123')).isTeacher, isFalse);
      expect((await client.register('ana', 'ana@correo.com', 'password123', teacherCode: 'secreto')).isTeacher, isTrue);
      await expectLater(client.register('ana', 'ana@correo.com', 'password123', teacherCode: 'malo'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Código de profesor inválido')));
      expect(bodies.first.containsKey('codigoProfesor'), isFalse);
      expect(bodies[1]['codigoProfesor'], 'secreto');
    });

    testWidgets('the register screen hides the teacher code until asked', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const RegisterScreen()));
      expect(find.text('Te lo da la institución'), findsNothing);

      await tester.ensureVisible(find.text('¿Eres profesor?'));
      await tester.tap(find.text('¿Eres profesor?'));
      await tester.pumpAndSettle();
      expect(find.text('Cuenta de profesor'), findsOneWidget);
      expect(find.text('Te lo da la institución'), findsOneWidget);

      await tester.ensureVisible(find.text('Soy estudiante'));
      await tester.tap(find.text('Soy estudiante'));
      await tester.pumpAndSettle();
      expect(find.text('Te lo da la institución'), findsNothing);
    });
  });

  group('teacher', () {
    const teacher = AuthUser(id: 23, username: 'profesor', email: 'profesor@questionsapp.com', points: 0, completedChallenges: 0, role: 'profesor');

    test('teachers get their own window and students the usual one', () {
      expect(teacher.isTeacher, isTrue);
      expect(shellFor(teacher), isA<TeacherShell>());
      expect(shellFor(AuthUser.fromJson({'id': 1, 'username': 'laura', 'rol': 'estudiante'})), isA<AppShell>());
    });

    testWidgets('starts on the students ranking', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const TeacherShell(user: teacher)));
      await tester.pumpAndSettle();
      expect(find.text('profesor'), findsOneWidget);
      expect(find.text('Clasificación'), findsOneWidget);
      expect(find.text('Página 1 de 1'), findsOneWidget);
      expect(find.text('Banco de preguntas'), findsNothing);
    });

    testWidgets('shows the question bank and a profile without stats', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const TeacherShell(user: teacher)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Preguntas'));
      await tester.pumpAndSettle();
      expect(find.text('profesor'), findsOneWidget);
      expect(find.text('Banco de preguntas'), findsOneWidget);
      expect(find.text('AGREGAR PREGUNTA'), findsOneWidget);

      await tester.tap(find.byTooltip('Perfil'));
      await tester.pumpAndSettle();
      expect(find.text('CERRAR SESIÓN'), findsOneWidget);
      expect(find.text('Puntos'), findsNothing);
      expect(find.text('Racha'), findsNothing);
      expect(find.text('Recorrido de hoy'), findsNothing);
    });

    test('loads the ranking ten students at a time', () async {
      final client = ApiClient(client: MockClient((request) async {
        expect(request.url.path, '/api/profesor/clasificacion');
        expect(request.url.queryParameters['pagina'], '2');
        return http.Response(
          jsonEncode({
            'clasificacion': [
              {'posicion': 11, 'id': 8, 'username': 'laura', 'puntos_totales': 4},
            ],
            'pagina': 2,
            'total': 11,
            'total_paginas': 2,
          }),
          200,
        );
      }));

      final page = await client.rankingPage(page: 2);
      expect((page.page, page.total, page.totalPages), (2, 11, 2));
      expect((page.entries.single.position, page.entries.single.username), (11, 'laura'));
    });

    test('loads the question bank one page at a time', () async {
      final client = ApiClient(client: MockClient((request) async {
        expect(request.url.path, '/api/profesor/preguntas');
        expect(request.url.queryParameters['pagina'], '2');
        return http.Response(
          jsonEncode({
            'preguntas': [
              {
                'id': 15,
                'enunciado': '¿Qué es una pila?',
                'puntos': 1,
                'activa': true,
                'opciones': [
                  {'id': 1, 'texto': 'LIFO', 'es_correcta': true},
                  {'id': 2, 'texto': 'FIFO', 'es_correcta': false},
                ],
              },
            ],
            'pagina': 2,
            'total': 21,
            'total_paginas': 5,
          }),
          200,
        );
      }));

      final page = await client.questionBank(page: 2);
      expect((page.page, page.total, page.totalPages), (2, 21, 5));
      expect(page.questions.single.correctOption?.text, 'LIFO');
    });

    test('creates a question with its four options and the correct one', () async {
      final client = ApiClient(client: MockClient((request) async {
        expect((request.method, request.url.path), ('POST', '/api/profesor/preguntas'));
        expect(jsonDecode(request.body), {
          'enunciado': '¿Qué es una cola?',
          'opciones': ['LIFO', 'FIFO', 'Árbol', 'Grafo'],
          'correcta': 1,
        });
        return http.Response(
          jsonEncode({
            'id': 21,
            'enunciado': '¿Qué es una cola?',
            'opciones': [
              {'id': 81, 'texto': 'LIFO', 'es_correcta': false},
              {'id': 82, 'texto': 'FIFO', 'es_correcta': true},
              {'id': 83, 'texto': 'Árbol', 'es_correcta': false},
              {'id': 84, 'texto': 'Grafo', 'es_correcta': false},
            ],
          }),
          201,
        );
      }));

      final created = await client.createQuestion(text: '¿Qué es una cola?', options: ['LIFO', 'FIFO', 'Árbol', 'Grafo'], correct: 1);
      expect(created.correctOption?.id, 82);
    });

    testWidgets('the new question form asks for every field and the correct option', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const NewQuestionScreen()));
      await tester.tap(find.text('GUARDAR PREGUNTA'));
      await tester.pump();
      expect(find.text('Escribe el enunciado'), findsOneWidget);
      expect(find.text('Escribe la opción'), findsNWidgets(4));

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '¿Qué es una cola?');
      for (final (index, option) in ['LIFO', 'FIFO', 'Árbol', 'Grafo'].indexed) {
        await tester.enterText(fields.at(index + 1), option);
      }
      await tester.ensureVisible(find.text('GUARDAR PREGUNTA'));
      await tester.tap(find.text('GUARDAR PREGUNTA'));
      await tester.pump();
      expect(find.text('Toca la letra de la opción correcta'), findsOneWidget);

      await tester.enterText(fields.at(4), 'lifo');
      await tester.tap(find.bySemanticsLabel('Marcar B como correcta'));
      await tester.ensureVisible(find.text('GUARDAR PREGUNTA'));
      await tester.tap(find.text('GUARDAR PREGUNTA'));
      await tester.pump();
      expect(find.text('Las opciones no pueden repetirse'), findsOneWidget);
    });
  });

  group('custom challenges', () {
    const challengeJson = {
      'id': 3,
      'titulo': 'Repaso de pilas',
      'codigo': 'SQ5JWN',
      'cantidad_preguntas': 3,
      'segundos_por_pregunta': 20,
      'da_puntos': false,
      'fecha_inicio': '2026-10-28T01:09:33.737Z',
      'fecha_fin': '2026-10-28T02:09:33.737Z',
      'activo': true,
      'estudiantes': 2,
    };

    test('parses the teacher results per option', () {
      final stats = ChallengeStats.fromJson({
        'reto': challengeJson,
        'estudiantes': 2,
        'preguntas': [
          {
            'id': 5,
            'posicion': 1,
            'enunciado': '¿Qué es una pila?',
            'sin_respuesta': 1,
            'estudiantes_sin_respuesta': ['marta'],
            'opciones': [
              {'id': 17, 'texto': 'LIFO', 'es_correcta': true, 'respuestas': 1, 'estudiantes': ['laura']},
              {'id': 18, 'texto': 'FIFO', 'es_correcta': false, 'respuestas': 0, 'estudiantes': []},
            ],
          },
        ],
      });
      expect(stats.challenge.code, 'SQ5JWN');
      expect(stats.challenge.givesPoints, isFalse);
      expect(stats.challenge.endsAt.isUtc, isFalse);
      final question = stats.questions.single;
      expect((question.timedOut, question.answers, question.options.first.count), (1, 2, 1));
      expect(question.timedOutStudents, ['marta']);
      expect(question.options.first.students, ['laura']);
      expect(question.options.last.students, isEmpty);
    });

    testWidgets('tapping how many chose an option lists those students', (tester) async {
      const question = QuestionStats(id: 5, position: 1, text: '¿Qué es una pila?', timedOut: 0, options: [
        OptionStats(id: 17, text: 'LIFO', isCorrect: true, count: 2, students: ['laura', 'pedro_gomez']),
        OptionStats(id: 18, text: 'FIFO', isCorrect: false, count: 0),
      ]);
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const Scaffold(body: QuestionResults(question: question))));
      expect(find.byTooltip('Ver estudiantes'), findsOneWidget);

      await tester.tap(find.text('2 · 100%'));
      await tester.pumpAndSettle();
      expect(find.text('Opción A (correcta)'), findsOneWidget);
      expect(find.text('laura'), findsOneWidget);
      expect(find.text('pedro_gomez'), findsOneWidget);
      expect(find.text('PG'), findsOneWidget);

      await tester.tap(find.text('Cerrar'));
      await tester.pumpAndSettle();
      expect(find.text('laura'), findsNothing);
      await tester.tap(find.text('0 · 0%').first);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    test('joins with the code in capitals and shows why it cannot', () async {
      final requested = <String>[];
      final client = ApiClient(client: MockClient((request) async {
        requested.add(request.url.path);
        if (request.url.path.endsWith('SQ5JWN')) {
          return http.Response(
            jsonEncode({
              'id': 3,
              'titulo': 'Repaso de pilas',
              'segundos_por_pregunta': 20,
              'da_puntos': false,
              'fecha_fin': '2026-10-28T02:09:33.737Z',
              'preguntas': [
                {'reto_id': 3, 'posicion': 1, 'id': 5, 'tipo': 'opcion_multiple', 'enunciado': '¿Pila?', 'puntos': 1, 'realizada': false, 'opciones': []},
              ],
            }),
            200,
          );
        }
        return http.Response(jsonEncode({'error': {'code': 'CHALLENGE_EXPIRED', 'message': 'Este reto ya terminó'}}), 410);
      }));

      final run = await client.joinCustomChallenge(' sq5jwn ');
      expect((run.code, run.secondsPerQuestion, run.givesPoints, run.questions.length), ('SQ5JWN', 20, false, 1));
      await expectLater(client.joinCustomChallenge('OLD234'), throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Este reto ya terminó')));
      expect(requested, ['/api/retos-personalizados/SQ5JWN', '/api/retos-personalizados/OLD234']);
    });

    test('creates a challenge with the chosen settings', () async {
      final client = ApiClient(client: MockClient((request) async {
        expect((request.method, request.url.path), ('POST', '/api/profesor/retos'));
        expect(jsonDecode(request.body), {'titulo': 'Repaso', 'preguntas': [5, 2], 'segundosPregunta': 30, 'daPuntos': true, 'duracionHoras': 72});
        return http.Response(jsonEncode(challengeJson), 201);
      }));
      final created = await client.createCustomChallenge(title: 'Repaso', questionIds: [5, 2], secondsPerQuestion: 30, givesPoints: true, durationHours: 72);
      expect(created.code, 'SQ5JWN');
    });

    testWidgets('a custom run uses its own timer and hides points when it gives none', (tester) async {
      const user = AuthUser(id: 1, username: 'laura', email: 'laura@example.com', points: 0, completedChallenges: 0, role: 'estudiante');
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: WeeklyRunScreen(
          user: user,
          title: 'Repaso de pilas',
          timeLimitSeconds: 30,
          givesPoints: false,
          questions: const [Question(id: 5, position: 1, type: 'opcion_multiple', text: '¿Pila?', points: 1, options: [QuestionOption(id: 17, text: 'LIFO')], completed: false)],
          submit: (question, optionId, elapsedSeconds) async => const AnswerResult(correct: true, points: 0, completedChallenges: 0),
        ),
      ));

      expect(find.text('30s'), findsOneWidget);
      expect(find.text('REPASO DE PILAS'), findsOneWidget);
      await tester.tap(find.text('LIFO'));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump();
      expect(find.text('¡Repaso de pilas completado!'), findsOneWidget);
      expect(find.text('1/1'), findsOneWidget);
      expect(find.text('Puntos ganados'), findsNothing);
    });

    testWidgets('teachers get a challenges tab', (tester) async {
      const teacher = AuthUser(id: 23, username: 'profesor', email: 'profesor@questionsapp.com', points: 0, completedChallenges: 0, role: 'profesor');
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const TeacherShell(user: teacher)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retos'));
      await tester.pumpAndSettle();
      expect(find.text('CREAR RETO'), findsOneWidget);
    });

    testWidgets('a new challenge needs a title and at least one question', (tester) async {
      await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: const NewChallengeScreen()));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('CREAR RETO'));
      await tester.tap(find.text('CREAR RETO'));
      await tester.pump();
      expect(find.text('Escribe un título'), findsOneWidget);
      expect(find.text('Elige al menos una pregunta'), findsOneWidget);
    });
  });
}
