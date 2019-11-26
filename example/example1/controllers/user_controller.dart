import 'package:liquid/src/common.dart';

import '../models/user.dart';

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
