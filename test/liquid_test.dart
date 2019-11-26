import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'package:liquid/liquid.dart';
import 'package:test/test.dart';

void main() {
  group('Common package', () {
    Application app;
    BaseClient client;

    setUp(() {
      client = http.Client();
      app = Application();
      app.listen(3000);
    });

    tearDown(() {
      app.close();
    });

    test('Inexistant url', () async {
      var response = await client.get('http://127.0.0.1:3000/');
      expect(response.statusCode, equals(404));
    });
  });
}
