import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'api/api_client.dart';
import 'screens/app_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'theme/app_tokens.dart';
import 'widgets/common.dart';

/// Permite volver al login desde fuera de cualquier pantalla cuando caduca la sesión.
final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Nunito']) {
      final license = await rootBundle.loadString('assets/fonts/OFL_$family.txt');
      yield LicenseEntryWithLineBreaks([family], license);
    }
  });
  apiClient.onSessionExpired = _backToLogin;
  runApp(const MyApp());
}

void _backToLogin() {
  final navigator = navigatorKey.currentState;
  if (navigator == null) return;
  navigator.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  ScaffoldMessenger.of(navigator.context).showSnackBar(SnackBar(content: Text(const SessionExpiredException().message)));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'QuestionsApp',
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
        theme: AppTheme.dark,
        // Fondo oscuro en todas las pantallas: iconos claros en la barra de estado.
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(value: SystemUiOverlayStyle.light, child: child!),
        home: const SessionGate(),
      );
}

/// Primera pantalla: recupera la sesión guardada y entra directo, o muestra el login.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  String? error;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() => error = null);
    try {
      final user = await apiClient.restoreSession();
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => user == null ? const LoginScreen() : shellFor(user)));
    } on ApiException catch (exception) {
      if (mounted) setState(() => error = exception.message);
    }
  }

  Future<void> _useAnotherAccount() async {
    await apiClient.logout();
    if (!mounted) return;
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.page),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const AppMark(pixel: 8),
              const SizedBox(height: Gap.xl),
              if (error == null) ...[
                Text('Cargando datos…', style: theme.textTheme.titleLarge),
                const SizedBox(height: Gap.lg),
                const CircularProgressIndicator(),
              ] else ...[
                NightCard(
                  child: StatusMessage(icon: Icons.cloud_off_rounded, title: 'Sin conexión', message: error!, actionLabel: 'Reintentar', onAction: _restore),
                ),
                const SizedBox(height: Gap.md),
                TextButton(onPressed: _useAnotherAccount, child: const Text('Cerrar sesión')),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
