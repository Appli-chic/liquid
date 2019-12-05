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
  List<Type> _controllerList = [];

  /// Set all the controllers
  void setControllers(List<Type> controllers) {
    _controllerList = controllers;
  }

  /// Close the server when we are done with it
  Future<void> close() async {
    await _server.close();
  }

  /// Creates a hot reload for the web server.
  void _addHotReload() async {
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
    print('The server is listening at ${_server.address.host}:${_server.port}');

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
    var exp = RegExp(r'(https?:\/\/.*):(\d*)\/?(.*)');
    var matches =
        exp.allMatches(request.requestedUri.toString()).toList();

    if (matches.isNotEmpty && matches.toList()[0].groupCount == 3) {
      var path = matches[0].group(3);
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
    var isMethodFound = false;
    var methods =
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
                  var doAllParamExists = true;
                  var params = request.requestedUri.queryParameters;

                  method = entry.value;
                  if (method.parameters != null &&
                      method.parameters.isNotEmpty) {
                    for (var param in method.parameters) {
                      var doParamExists = false;

                      for (var metadata in param.metadata) {
                        if (MirrorSystem.getName(metadata.type.simpleName) ==
                            'Param') {
                          if (params.containsKey(metadata.reflectee.name)) {
                            doParamExists = true;
                          }
                        } else if (MirrorSystem.getName(
                                metadata.type.simpleName) ==
                            'Body') {
                          doParamExists = true;
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
    var indexControllerPath =
        path.indexOf(controllerPath) + controllerPath.length;

    if ((methodPath == '/' && indexControllerPath == path.length) ||
        path == '$controllerPath$methodPath') {
      return true;
    } else {
      var paramList = <String>[];

      if (request.requestedUri.queryParameters.isNotEmpty) {
        for (var param in request.requestedUri.queryParameters.entries) {
          for (var paramMethod in method.parameters) {
            for (var metadata in paramMethod.metadata) {
              var paramName = MirrorSystem.getName(metadata.type.simpleName);
              if (paramName == 'Param') {
                if (metadata.reflectee.name == param.key) {
                  paramList.add(paramName);
                }
              } else if (paramName == 'Body') {
                paramList.add(paramName);
              }
            }
          }
        }
      }

      if (paramList.length == request.requestedUri.queryParameters.length) {
        if ((methodPath == '/' && indexControllerPath == path.length) ||
            path.split('?')[0] == '$controllerPath$methodPath' ||
            '${path.split('?')[0]}/' == '$controllerPath$methodPath') {
          return true;
        }
      }
    }

    return false;
  }

  /// Decode the body contained in the [request]
  dynamic _decodeBody(HttpRequest request, ParameterMirror param) async {
    var body = await Utf8Codec().decodeStream(request);
    var type = param.type;

    // Parse the result with the wanted param type
    if (type.isAssignableTo(reflectType(String))) {
      return body;
    } else if (type.isAssignableTo(reflectType(int))) {
      return int.parse(body);
    } else if (type.isAssignableTo(reflectType(double))) {
      return double.parse(body);
    } else if (type.isAssignableTo(reflectType(bool))) {
      if (body == 'true') {
        return true;
      } else {
        return false;
      }
    } else if (type.isAssignableTo(reflectType(List))) {
      var argumentType = type.typeArguments[0];
      dynamic decodedBody = json.decode(body);
      ClassMirror clsMirror = reflectType(List, [argumentType.reflectedType]);
      var result = clsMirror.newInstance(const Symbol(''), []).reflectee;

      for (var item in decodedBody) {
        result.add(_parseJsonToObject(item, argumentType));
      }

      return result;
    } else if (type.isAssignableTo(reflectType(Set))) {
      return json.encode(body);
    } else if (type.isAssignableTo(reflectType(Map))) {
      return json.encode(body);
    } else {
      var argumentType = type.typeArguments[0];
      dynamic decodedBody = json.decode(body);
      return _parseJsonToObject(decodedBody, argumentType);
    }
  }

  /// Parse JSON into an object
  dynamic _parseJsonToObject(dynamic item, TypeMirror type) {
    var valueInstance = reflect(item);

    if (type.isAssignableTo(reflectType(String))) {
      return item;
    } else if (type.isAssignableTo(reflectType(int))) {
      if (valueInstance.type.isAssignableTo(reflectType(int))) {
        return item;
      } else {
        return int.parse(item);
      }
    } else if (type.isAssignableTo(reflectType(double))) {
      if (valueInstance.type.isAssignableTo(reflectType(double))) {
        return item;
      } else {
        return double.parse(item);
      }
    } else if (type.isAssignableTo(reflectType(bool))) {
      if (valueInstance.type.isAssignableTo(reflectType(bool))) {
        return item;
      } else {
        if (item == 'true') {
          return true;
        } else {
          return false;
        }
      }
    } else if (type.isAssignableTo(reflectType(List))) {
      var argumentType = type.typeArguments[0];
      var decodedBody = item is String ? json.decode(item) : item;
      ClassMirror clsMirror = reflectType(List, [argumentType.reflectedType]);
      var result = clsMirror.newInstance(const Symbol(''), []).reflectee;

      for (var item in decodedBody) {
        result.add(_parseJsonToObject(item, argumentType));
      }

      return result;
    } else if (type.isAssignableTo(reflectType(Set))) {
      var argumentType = type.typeArguments[0];
      var decodedBody = item is String ? json.decode(item) : item;
      ClassMirror clsMirror = reflectType(Set, [argumentType.reflectedType]);
      var result = clsMirror.newInstance(const Symbol(''), []).reflectee;

      for (var item in decodedBody) {
        result.add(_parseJsonToObject(item, argumentType));
      }

      return result;
    } else if (type.isAssignableTo(reflectType(Map))) {
      return json.encode(item);
    } else {
      var model = reflectClass(type.reflectedType);
      var result = model.newInstance(Symbol(''), []);

      // Find all the declarations from the type
      var declarations = model.declarations;
      var objectMap = item as Map<String, dynamic>;

      // Add the data of each fields contained in this object
      declarations.forEach((Symbol key, DeclarationMirror declaration) {
        if (declaration is VariableMirror) {
          for (var field in objectMap.entries) {
            if (field.key == MirrorSystem.getName(declaration.simpleName)) {
              var value = _parseJsonToObject(field.value, declaration.type);
              result.setField(declaration.simpleName, value);
            }
          }
        }
      });

      return result.reflectee;
    }
  }

  /// Call the [method] and create a response from the answer of this one
  void _callMethod(HttpRequest request, dynamic controller, MethodMirror method,
      Response response) async {
    // Instanciate the controller
    var apiController = reflectClass(controller).newInstance(Symbol(''), []);

    // Add the parameters
    var paramValues = <dynamic>[];
    var params = request.requestedUri.queryParameters;
    for (var param in method.parameters) {
      for (var metadata in param.metadata) {
        if (MirrorSystem.getName(metadata.type.simpleName) == 'Param') {
          if (params.containsKey(metadata.reflectee.name)) {
            paramValues.add(params[metadata.reflectee.name]);
          }
        } else if (MirrorSystem.getName(metadata.type.simpleName) == 'Body') {
          paramValues.add(await _decodeBody(request, param));
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

    await httpResponse.close();
  }

  /// Create a [response] according to the type from the returned [value]
  void _createResponseFromType(HttpResponse response, dynamic value) {
    if (value is String || value is int || value is double) {
      response.headers.contentType = ContentType.text;
      response.write(value);
    } else if (value is bool) {
      response.headers.contentType = ContentType.text;
      response.write(value ? 'true' : 'false');
    } else if (value is List || value is Set) {
      response.headers.contentType = ContentType.json;
      var jsonResponse = _parseObjectToJson(value);
      response.write(json.encode(jsonResponse));
    } else if (value is Map) {
    } else {
      // Should parse to json
      response.headers.contentType = ContentType.json;
      var jsonResponse = _parseObjectToJson(value);
      response.write(json.encode(jsonResponse));
    }
  }

  /// Transforms objects [value] into JSON data
  dynamic _parseObjectToJson(dynamic value) {
    var result = HashMap<String, dynamic>();
    var valueInstance = reflect(value);
    var valueType = valueInstance.type;

    if (value is String || value is int || value is double || value is bool) {
    } else if (value is List) {
      return value.map((e) => _parseObjectToJson(e)).toList();
    } else if (value is Set) {
      return value.map((e) => _parseObjectToJson(e)).toSet();
    } else if (value is Map) {
    } else {
      // Find all the declarations from the type
      var declarations =
          reflectClass(valueType.reflectedType).declarations;

      // Add the data of each fields contained in this object
      declarations.forEach((Symbol key, DeclarationMirror declaration) {
        if (declaration is VariableMirror) {
          var field = declaration.simpleName;
          var fieldName = MirrorSystem.getName(field);
          var fieldValue = valueInstance.getField(field).reflectee;

          if (fieldName != null) {
            if (fieldValue is String ||
                fieldValue is int ||
                fieldValue is double ||
                fieldValue is bool) {
            } else if (fieldValue is List) {
              fieldValue =
                  fieldValue.map((e) => _parseObjectToJson(e)).toList();
            } else if (fieldValue is Set) {
              fieldValue = fieldValue.map((e) => _parseObjectToJson(e)).toSet();
            } else if (fieldValue is Map) {
            } else {
              // Should parse to json
              fieldValue = _parseObjectToJson(fieldValue);
            }

            result[fieldName] = fieldValue;
          }
        }
      });
    }

    return result;
  }
}
