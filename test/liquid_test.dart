import 'package:liquid/liquid.dart';
import 'package:test/test.dart';

void main() {
  group('A group of tests', () {
    Application app;

    setUp(() async {
      app = Application();
      await app.listen(3000);
    });

    test('First Test', () {});
  });
}
