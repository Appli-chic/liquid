import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'dart:mirrors';

import 'package:jaguar_hotreload/jaguar_hotreload.dart';
import 'dart:developer' as dev;
import 'package:path/path.dart' as path;

import 'common.dart';
import 'response.dart';

class Application {
  HttpServer _server;
  List<dynamic> _controllerList = [];
  addController(dynamic controller) {
    _controllerList.add(controller);
  }

  /// Close the server when we are done with it
  Future<void> close() async {
    await _server.close();
  }

  /// Creates a hot reload for the web server.
  _addHotReload() async {
    if (HotReloader.isHotReloadable) {
      var info = await dev.Service.getInfo();
      var uri = info.serverUri;
      uri = uri.replace(path: path.join(uri.path, 'ws'));
      if (uri.scheme == 'https') {
        uri = uri.replace(scheme: 'wss');
      } else {
        uri = uri.replace(scheme: 'ws');
      }

      print('Hot reloading enabled');
      final reloader = HotReloader(vmServiceUrl: uri.toString());
      await reloader.addPath('.');
      await reloader.go();
    }
  }

  /// Listen to the specific [port] and initialize the [_server]
  /// Catches all the server's requests
  Future<void> listen(int port) async {
    _addHotReload();
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    print("The server is listening at ${_server.address.host}:${_server.port}");

    await for (HttpRequest request in _server) {
      var methodFound = _redirectRequestsToControllers(request);

      if (!methodFound) {
        var response = request.response;
        response.statusCode = 404;
        await response.close();
      }
    }
  }

  /// Redirect the [request] to the wanted controller
  bool _redirectRequestsToControllers(HttpRequest request) {
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
          var methodFound =
              _checkingEachMethods(request, controller, controllerPath, path);

          if (methodFound) {
            return true;
          }
        }
      }
    }

    return false;
  }

  /// Read the information of each methods from a [controller] class containing the right path.
  /// If one method contains the right path then we will call it.
  bool _checkingEachMethods(HttpRequest request, dynamic controller,
      String controllerPath, String path) {
    MethodMirror method;
    bool isMethodFound = false;
    Map<Symbol, MethodMirror> methods =
        reflectClass(controller).instanceMembers;

    // Browse each methods from the controller
    for (var entry in methods.entries) {
      // Browse through the metadata values
      if (!isMethodFound) {
        for (var metadata in entry.value.metadata) {
          var metadataValue = metadata.reflectee;

          // Check if the metadata name is corresponding to the http methods
          if (methodList
              .contains(MirrorSystem.getName(metadata.type.simpleName))) {
            String methodPath = metadataValue.path;

            // Check if the path is corresponding controller + function path
            if (methodPath != null) {
              if (request.method ==
                  MirrorSystem.getName(metadata.type.simpleName)
                      .toUpperCase()) {
                if (_checkUrlIsCorresponding(
                    request, controllerPath, path, methodPath, entry.value)) {
                  // Check if the right arguments are given
                  bool doAllParamExists = true;
                  var params = request.requestedUri.queryParameters;

                  method = entry.value;
                  if (method.parameters != null &&
                      method.parameters.isNotEmpty) {
                    for (var param in method.parameters) {
                      bool doParamExists = false;

                      for (var metadata in param.metadata) {
                        if (MirrorSystem.getName(metadata.type.simpleName) ==
                            "Param") {
                          if (params.containsKey(metadata.reflectee.name)) {
                            doParamExists = true;
                          }
                        }
                      }

                      if (!doParamExists) {
                        doAllParamExists = false;
                        break;
                      }
                    }
                  }

                  if (doAllParamExists) {
                    isMethodFound = true;
                    break;
                  }
                }
              }
            }
          }
        }
      }
    }

    // If the method is found, we add all the metadata to the query and call the method
    if (isMethodFound) {
      var response = Response();

      for (var metadata in method.metadata) {
        if (MirrorSystem.getName(metadata.type.simpleName) == 'Status') {
          response.statusCode = metadata.reflectee.code;
        } else if (MirrorSystem.getName(metadata.type.simpleName) == 'Header') {
          response.headers[metadata.reflectee.header] =
              metadata.reflectee.value;
        }
      }

      _callMethod(request, controller, method, response);
    }

    return isMethodFound;
  }

  /// Check if the url is corresponding to the method url
  bool _checkUrlIsCorresponding(HttpRequest request, String controllerPath,
      String path, String methodPath, MethodMirror method) {
    int indexControllerPath =
        path.indexOf(controllerPath) + controllerPath.length;

    if ((methodPath == '/' && indexControllerPath == path.length) ||
        path == '$controllerPath$methodPath') {
      return true;
    } else {
      List<String> paramList = List();

      if (request.requestedUri.queryParameters.isNotEmpty) {
        for (var param in request.requestedUri.queryParameters.entries) {
          for (var paramMethod in method.parameters) {
            for (var metadata in paramMethod.metadata) {
              String paramName = MirrorSystem.getName(metadata.type.simpleName);
              if (paramName == "Param") {
                if (metadata.reflectee.name == param.key) {
                  paramList.add(paramName);
                }
              }
            }
          }
        }
      }

      if (paramList.length == request.requestedUri.queryParameters.length) {
        if ((methodPath == '/' && indexControllerPath == path.length) ||
            path.split('?')[0] == '$controllerPath$methodPath') {
          return true;
        }
      }
    }

    return false;
  }

  /// Call the [method] and create a response from the answer of this one
  _callMethod(HttpRequest request, dynamic controller, MethodMirror method,
      Response response) {
    // Instanciate the controller
    var apiController = reflectClass(controller).newInstance(Symbol(""), []);

    // Add the parameters
    var paramValues = List<dynamic>();
    var params = request.requestedUri.queryParameters;
    for (var param in method.parameters) {
      for (var metadata in param.metadata) {
        if (MirrorSystem.getName(metadata.type.simpleName) == "Param") {
          if (params.containsKey(metadata.reflectee.name)) {
            paramValues.add(params[metadata.reflectee.name]);
          }
        }
      }
    }

    // Call the method
    var valueInstanceMirror =
        apiController.invoke(method.simpleName, paramValues);
    var value = valueInstanceMirror.reflectee;

    var httpResponse = request.response;
    httpResponse.statusCode = response.statusCode;

    for (var header in response.headers.entries) {
      httpResponse.headers.add(header.key, header.value);
    }

    // Write the response if a value is returned
    if (value != null) {
      _createResponseFromType(httpResponse, value);
    }

    httpResponse.close();
  }

  /// Create a [response] according to the type from the returned [value]
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

  /// Transforms objects [value] into JSON data
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
