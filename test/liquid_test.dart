import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/http.dart';

import 'package:liquid/liquid.dart';
import 'package:liquid/src/common.dart';
import 'package:test/test.dart';

class Role {
  String name;

  Role({
    this.name,
  });
}

class User {
  int id;
  String name;
  List<Role> roles;

  User({
    this.id,
    this.name,
    this.roles,
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
  @Post('/name')
  User postUserWithName(@Body() String name) {
    return User(id: 0, name: name);
  }

  @Status(201)
  @Post('/id')
  User postUserWithId(@Body() int id) {
    return User(id: id, name: 'Guillaume Belouin');
  }

  @Status(201)
  @Post('/list')
  List<User> postUserList(@Body() List<User> userList) {
    return userList;
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
        'roles': {},
        'name': 'Guillaume Belouin',
        'id': 0,
      });
    });

    test('Get user by name API', () async {
      var response = await client.get('http://127.0.0.1:3000/users/?name=test');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'roles': {},
        'name': 'test',
        'id': 0,
      });
    });

    test('Get user by name without / API', () async {
      var response = await client.get('http://127.0.0.1:3000/users?name=test');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'roles': {},
        'name': 'test',
        'id': 0,
      });
    });

    test('POST user with header and status defined with name', () async {
      var response = await client.post('http://127.0.0.1:3000/users/name',
          body: 'Guillaume Belouin');
      expect(response.statusCode, equals(201));
      expect(json.decode(response.body), {
        'roles': {},
        'name': 'Guillaume Belouin',
        'id': 0,
      });

      var doHeaderIsCorrect = false;

      for (var header in response.headers.entries) {
        if (header.key == 'test-header' && header.value == 'test-value') {
          doHeaderIsCorrect = true;
        }
      }

      expect(doHeaderIsCorrect, equals(true));
    });

    test('POST user with id', () async {
      var response =
          await client.post('http://127.0.0.1:3000/users/id', body: '1');
      expect(response.statusCode, equals(201));
      expect(json.decode(response.body), {
        'roles': {},
        'name': 'Guillaume Belouin',
        'id': 1,
      });
    });

    test('POST users from List body', () async {
      var response = await client.post('http://127.0.0.1:3000/users/list',
          body: json.encode([
            {
              'name': 'Guillaume Belouin',
              'id': 0,
              'roles': [
                {'name': 'Admin'},
                {'name': 'User'}
              ]
            },
            {
              'name': 'Jocelyn Zaruma',
              'id': 1,
              'roles': [
                {'name': 'Moderator'},
                {'name': 'User'}
              ]
            },
          ]));
      expect(response.statusCode, equals(201));
      expect(json.decode(response.body), [
        {
          'name': 'Guillaume Belouin',
          'id': 0,
          'roles': [
            {'name': 'Admin'},
            {'name': 'User'}
          ]
        },
        {
          'name': 'Jocelyn Zaruma',
          'id': 1,
          'roles': [
            {'name': 'Moderator'},
            {'name': 'User'}
          ]
        },
      ]);
    });

    test('PUT user', () async {
      var response = await client.put('http://127.0.0.1:3000/users');
      expect(response.statusCode, equals(200));
      expect(json.decode(response.body), {
        'roles': {},
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
        'roles': {},
        'name': 'Guillaume Belouin patched',
        'id': 0,
      });
    });
  });
}
