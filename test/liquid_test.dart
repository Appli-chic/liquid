import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'package:liquid/liquid.dart';
import 'package:liquid/src/common.dart';
import 'package:test/test.dart';

class User {
  int id;
  String name;

  User({
    this.id,
    this.name,
  });
}

@Controller('users')
class UserController {
  @Get('/')
  User getUser() {
    return User(id: 0, name: 'Guillaume Belouin');
  }

  @Get('/')
  User getUserByName(@Param('name') String name) {
    return User(id: 0, name: name);
  }

  @Status(201)
  @Header('test-header', 'test-value')
  @Post('/')
  User postUser() {
    return User(id: 0, name: 'Guillaume Belouin created');
  }

  @Put('/')
  User putUser() {
    return User(id: 0, name: 'Guillaume Belouin put');
  }

  @Delete('/')
  bool deleteUser() {
    return true;
  }

  @Patch('/')
  User patchUser() {
    return User(id: 0, name: 'Guillaume Belouin patched');
  }

  @Get('/text')
  String getUserText() {
    return 'Guillaume Belouin';
  }
}

void main() {
  group('Controllers', () {
    Application app;
    BaseClient client;

    setUpAll(() {
      client = http.Client();
      app = Application();

      app.setControllers([
        UserController,
      ]);

      app.listen(3000);
    });

    tearDownAll(() {
      app.close();
    });

    test('Inexistant url', () async {
      var response = await client.get('http://127.0.0.1:3000/');
      expect(response.statusCode, equals(404));
    });

    test('Send text API', () async {
      var response = await client.get('http://127.0.0.1:3000/users/text');
      expect(response.statusCode, equals(200));
      expect(response.body, 'Guillaume Belouin');
    });

    test('Get user API', () async {
      var response = await client.get('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'name': 'Guillaume Belouin',
        'id': 0,
      });
    });

    test('Get user by name API', () async {
      var response = await client.get('http://127.0.0.1:3000/users/?name=test');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'name': 'test',
        'id': 0,
      });
    });

    test('Get user by name without / API', () async {
      var response = await client.get('http://127.0.0.1:3000/users?name=test');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'name': 'test',
        'id': 0,
      });
    });

    test('POST user with header and status defined', () async {
      var response = await client.post('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(201));
      expect(json.decode(response.body), {
        'name': 'Guillaume Belouin created',
        'id': 0,
      });

      bool doHeaderIsCorrect = false;

      for (var header in response.headers.entries) {
        if (header.key == 'test-header' && header.value == 'test-value') {
          doHeaderIsCorrect = true;
        }
      }

      expect(doHeaderIsCorrect, equals(true));
    });

    test('PUT user', () async {
      var response = await client.put('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'name': 'Guillaume Belouin put',
        'id': 0,
      });
    });

    test('DELETE user', () async {
      var response = await client.delete('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(200));
      expect(response.body, equals('true'));
    });

    test('PATCH user', () async {
      var response = await client.patch('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'name': 'Guillaume Belouin patched',
        'id': 0,
      });
    });
  });
}
