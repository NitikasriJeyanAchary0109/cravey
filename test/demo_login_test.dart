import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tomatoo/services/api_client.dart';
import 'package:tomatoo/services/auth_service.dart';
import 'package:tomatoo/services/session_provider.dart';

/// Answers /api/auth/demo-login with a canned reply and everything else with 404 (the profile calls after sign-in just fail quietly).
class _Backend implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  int demoStatus = 200;
  Map<String, dynamic> demoBody = {'accessToken': 'token-from-server', 'email': 'aarav.sharma@gmail.com', 'name': 'Aarav Sharma', 'role': 'CUSTOMER', 'userId': 7};

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    final isDemo = options.path == '/api/auth/demo-login';
    return ResponseBody.fromString(jsonEncode(isDemo ? demoBody : {'message': 'Not found'}), isDemo ? demoStatus : 404,
        headers: {Headers.contentTypeHeader: [Headers.jsonContentType]});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Backend backend;
  late HttpClientAdapter rawBefore, dioBefore;

  setUp(() {
    backend = _Backend();
    rawBefore = ApiClient.instance.rawDio.httpClientAdapter;
    dioBefore = ApiClient.instance.dio.httpClientAdapter;
    ApiClient.instance.rawDio.httpClientAdapter = backend;
    ApiClient.instance.dio.httpClientAdapter = backend;
    AuthService.instance.setTokensForTesting(accessToken: null, refreshToken: null);
  });

  tearDown(() {
    ApiClient.instance.rawDio.httpClientAdapter = rawBefore;
    ApiClient.instance.dio.httpClientAdapter = dioBefore;
    AuthService.instance.setTokensForTesting(accessToken: null, refreshToken: null);
  });

  test('the app holds no signing key: nothing in lib contains the one the backend falls back to', () {
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      if (f.readAsStringSync().contains('change-this-to-a-secure-random-string')) offenders.add(f.path);
    }
    expect(offenders, isEmpty);
    expect(File('lib/services/jwt_helper.dart').existsSync(), isFalse);
  });

  test('demo sign-in asks the backend for the role and uses the token it is given', () async {
    final session = SessionProvider();
    await session.loginAsDemo('owner');
    final req = backend.requests.first;
    expect(req.method, 'POST');
    expect(req.path, '/api/auth/demo-login');
    expect((req.data as Map)['role'], 'OWNER');
    expect(AuthService.instance.isLoggedIn, isTrue);
    expect(session.user!.email, 'aarav.sharma@gmail.com', reason: 'who you are signed in as is whatever the server says');
    expect(session.user!.userId, 7);
    expect(session.effectiveRole, 'OWNER');
  });

  test('the request carries nothing but the role, so the app cannot ask for an arbitrary account', () async {
    await SessionProvider().loginAsDemo('CUSTOMER');
    expect((backend.requests.first.data as Map).keys, ['role']);
  });

  test('a server without the demo profile gives a plain message and leaves you signed out', () async {
    backend.demoStatus = 404;
    backend.demoBody = {'message': 'Not found'};
    final session = SessionProvider();
    await expectLater(session.loginAsDemo('CUSTOMER'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('not available on this server'))));
    expect(AuthService.instance.isLoggedIn, isFalse);
    expect(session.user, isNull);
  });

  test('a demo account that is missing is reported as such, not as an unavailable server', () async {
    backend.demoStatus = 404;
    backend.demoBody = {'message': 'The demo account for CUSTOMER does not exist yet.'};
    await expectLater(SessionProvider().loginAsDemo('CUSTOMER'), throwsA(isA<ApiException>().having((e) => e.message, 'message', contains('demo account'))));
  });

  test('any other failure keeps the server message and signs nobody in', () async {
    backend.demoStatus = 400;
    backend.demoBody = {'message': 'Choose CUSTOMER, OWNER, DELIVERY or ADMIN.'};
    await expectLater(SessionProvider().loginAsDemo('NONSENSE'), throwsA(isA<ApiException>()));
    expect(AuthService.instance.isLoggedIn, isFalse);
  });
}
