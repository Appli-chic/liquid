import 'package:liquid/liquid.dart';
import 'package:liquid/src/controller.dart';

class User {
  int id;
  String name;

  User({
    this.id,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
      };
}

@Controller('users')
class UserController {
  @Get('/')
  User getUser() {
    return User(id: 0, name: 'Guillaume Belouin');
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
