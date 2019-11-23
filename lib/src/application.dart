import 'dart:collection';
import 'dart:convert';
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

  /// Redirect the [request] to the wanted controller
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
          _checkingEachMethods(request, controller, controllerPath, path);
        }
      }
    }
  }

  /// Read the information of each methods from a [controller] class containing the right path.
  /// If one method contains the right path then we will call it.
  _checkingEachMethods(HttpRequest request, dynamic controller,
      String controllerPath, String path) {
    Map<Symbol, MethodMirror> methods =
        reflectClass(controller).instanceMembers;

    methods.forEach((Symbol symbol, MethodMirror method) {
      var metadataValue = method.metadata.first.reflectee;

      try {
        if (metadataValue.path != null) {
          String methodPath = metadataValue.path;
          int indexControllerPath =
              path.indexOf(controllerPath) + controllerPath.length;

          if (methodPath != null) {
            if (methodPath == '/' && indexControllerPath == path.length) {
              _callMethod(request, controller, method);
            } else if (path == '$controllerPath$methodPath') {
              _callMethod(request, controller, method);
            }
          }
        }
      } catch (e) {
        print(e);
      }
    });
  }

  /// Call the [method] and create a response from the answer of this one
  _callMethod(HttpRequest request, dynamic controller, MethodMirror method) {
    var apiController = reflectClass(controller).newInstance(Symbol(""), []);
    var valueInstanceMirror = apiController.invoke(method.simpleName, []);
    var value = valueInstanceMirror.reflectee;

    var response = request.response;

    // Write the response if a value is returned
    if (value != null) {
      _createResponseFromType(response, value);
    }

    response.close();
  }

  /// Create a response according to the type
  _createResponseFromType(HttpResponse response, dynamic value) {
    if (value is String || value is int || value is double) {
      response.headers.contentType = ContentType.text;
      response.write(value);
    } else if (value is bool) {
      response.headers.contentType = ContentType.text;
      response.write(value ? 'true' : 'false');
    } else if (value is List) {
    } else if (value is Set) {
    } else if (value is Map) {
    } else {
      // Should parse to json
      response.headers.contentType = ContentType.json;
      String jsonResponse = _parseObjectToJson(value);
      response.write(jsonResponse);
    }
  }

  /// Transforms objects into JSON data
  String _parseObjectToJson(dynamic value) {
    var result = HashMap<String, dynamic>();
    InstanceMirror valueInstance = reflect(value);
    ClassMirror valueType = valueInstance.type;

    // Find all the declarations from the type
    Map<Symbol, DeclarationMirror> declarations =
        reflectClass(valueType.reflectedType).declarations;

    // Add the data of each fields contained in this object
    declarations.forEach((Symbol key, DeclarationMirror declaration) {
      if (declaration is VariableMirror) {
        Symbol field = declaration.simpleName;
        String fieldName = MirrorSystem.getName(field);
        var fieldValue = valueInstance.getField(field).reflectee;
        result[fieldName] = fieldValue;
      }
    });

    return json.encode(result);
  }
}
