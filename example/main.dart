import 'package:liquid/liquid.dart';
import 'package:liquid/src/controller.dart';

@Controller('users')
class UserController {

  @Get('/')
  String getUser() {
    return 'users b764';
  }
}

main() async {
  var app = Application();
  app.addController(UserController);
  await app.listen(3000);
}
