import 'package:liquid/liquid.dart';

import 'controllers/user_controller.dart';

main() async {
  var app = Application();
  app.addController(UserController);
  await app.listen(3000);
}
