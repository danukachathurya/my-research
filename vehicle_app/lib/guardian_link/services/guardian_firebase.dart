import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

import '../firebase_options.dart' as guardian_options;

class GuardianFirebase {
  static const String appName = 'guardianLink';
  static FirebaseApp? _app;

  static Future<FirebaseApp> ensureInitialized() async {
    if (_app != null) {
      return _app!;
    }

    for (final app in Firebase.apps) {
      if (app.name == appName) {
        _app = app;
        return app;
      }
    }

    _app = await Firebase.initializeApp(
      name: appName,
      options: guardian_options.DefaultFirebaseOptions.currentPlatform,
    );
    return _app!;
  }

  static FirebaseApp get app {
    final app = _app;
    if (app == null) {
      throw StateError(
        'GuardianLink Firebase has not been initialized. Call '
        'GuardianFirebase.ensureInitialized() first.',
      );
    }
    return app;
  }

  static FirebaseAuth get auth => FirebaseAuth.instanceFor(app: app);

  static FirebaseDatabase get database => FirebaseDatabase.instanceFor(
    app: app,
    databaseURL: app.options.databaseURL,
  );
}
