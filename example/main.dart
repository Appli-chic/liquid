import 'package:liquid/liquid.dart';
import 'package:liquid/src/common.dart';

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

  @Get('/text')
  String getUserText() {
    return 'Guillaume Belouin';
  }
}

main() async {
  var app = Application();
  app.addController(UserController);
  await app.listen(3000);
}
