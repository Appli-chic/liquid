import 'dart:io';

import 'dart:mirrors';

class Application {
  HttpServer _server;
  List<dynamic> _controllerList = [];

  addController(dynamic controller) {
    _controllerList.add(controller);
  }

  /// Listen to the specific [port] and initialize the [_server]
  /// Catches all the server's requests
  Future<void> listen(int port) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print("The server is listening at ${_server.address.host}:${_server.port}");

    await for (HttpRequest request in _server) {
      _redirectRequestsToControllers(request);
    }
  }

  /// Redirect the requests to the specific controllers
  _redirectRequestsToControllers(HttpRequest request) {
    RegExp exp = RegExp(r'(https?:\/\/.*):(\d*)\/?(.*)');
    List<RegExpMatch> matches =
        exp.allMatches(request.requestedUri.toString()).toList();

    if (matches.isNotEmpty && matches.toList()[0].groupCount == 3) {
      String path = matches[0].group(3);
      for (var controller in _controllerList) {
        // Check if a controller contains this path
        String controllerPath =
            reflectClass(controller).metadata.first.reflectee.path;
        if (path.startsWith(controllerPath)) {
          // Check if one of the methods should answer
          Map<Symbol, MethodMirror> methods =
              reflectClass(controller).instanceMembers;

          methods.forEach((Symbol symbol, MethodMirror method) {
            var metadataValue = method.metadata.first.reflectee;

            try {
              if (metadataValue.path != null) {
                String methodPath = metadataValue.path;
                int indexControllerPath =
                    path.indexOf(controllerPath) + controllerPath.length;

                if ((methodPath != null && methodPath == '/') &&
                    indexControllerPath == path.length) {
                  // Call this method
                  var apiController = reflectClass(controller).newInstance(Symbol(""), []);
                  var valueInstanceMirror = apiController.invoke(method.simpleName, []);
                  var value = valueInstanceMirror.reflectee;

                  var response = request.response;
                  response.headers.contentType =
                      ContentType("text", "plain", charset: "utf-8");
                  response.write(value);
                  response.close();
                }
              }
            } catch (e) {
              print(e);
            }
          });
        }
      }
    }
  }
}
