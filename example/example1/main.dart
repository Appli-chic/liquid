import 'package:liquid/liquid.dart';

import 'controllers/user_controller.dart';

main() async {
  var app = Application();
  app.setControllers([
    UserController,
  ]);

  await app.listen(3000);
}
