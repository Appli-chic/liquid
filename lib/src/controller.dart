const methodList = [
  'Get',
  'Post',
  'Put',
  'Delete',
  'Patch',
];

/// Defines the root path for all the functions in the controller
class Controller {
  final String path;

  const Controller(this.path) : assert(path != null);
}

/// Defines the status the function should return if everything is allright
class Status {
  final int code;

  const Status(this.code) : assert(code != null);
}

/// Defines the path to access to the function which the request is asking a GET method
class Get {
  final String path;

  const Get(this.path) : assert(path != null);
}

/// Defines the path to access to the function which the request is asking a POST method
class Post {
  final String path;

  const Post(this.path) : assert(path != null);
}

/// Defines the path to access to the function which the request is asking a PUT method
class Put {
  final String path;

  const Put(this.path) : assert(path != null);
}

/// Defines the path to access to the function which the request is asking a DELETE method
class Delete {
  final String path;

  const Delete(this.path) : assert(path != null);
}

/// Defines the path to access to the function which the request is asking a PATCH method
class Patch {
  final String path;

  const Patch(this.path) : assert(path != null);
}
