library;

import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:build/build.dart';
import 'package:glob/glob.dart';
import 'package:routable_annotations/routable_annotations.dart';
import 'package:source_gen/source_gen.dart';

extension Capitalization on String {
  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String unCapitalize() {
    return '${this[0].toLowerCase()}${substring(1)}';
  }
}

class ConfigGenerator extends GeneratorForAnnotation<RouteConfig> {
  tree(List a, int i, Map v) {
    if (i < a.length) {
      tree(a, i + 1, v[a[i]] ??= {});
    }
  }

  // Function to convert a simple node into the desired record format.
  List<Map> record(Map v, List<Map> data, [Map? parent]) {
    final a = <Map>[];
    for (final entry in v.entries) {
      final rec = data.firstWhere((e) {
        final available = e['name'] == entry.key;
        final on = (e['on'] != null && parent != null)
            ? e['on'] == parent['name']
            : true;
        return available && on;
      });
      final path =
          parent != null ? rec["path"].replaceFirst('/', '') : rec["path"];
      final current = {
        ...rec,
        "full_path": [if (parent != null) parent["full_path"], path]
            .join("/")
            .replaceFirst('//', '/'),
        "path": path,
      };
      a.add({...current, "children": record(entry.value, data, current)});
    }
    return a;
  }

  String buildRoute(Map v) {
    final List<String> params = [];
    patternToRegExp(
        v['force_params'] == true ? v['full_path'] : v['path'], params);

    final paramsList =
        params.map((e) => "$e: state.pathParameters[\"$e\"]").join(", ");
    final extras =
        v['extra'] != null ? "params: state.extra as ${v['extra']}?" : "";
    final queryParams = v['use_query_params'] == true
        ? "queryParams: state.uri.queryParameters"
        : "";

    final List<String> arguments = [
      if (paramsList != "") paramsList,
      if (extras != "") extras,
      if (queryParams != "") queryParams,
    ];

    return """
GoRoute(
  path: "${v['path']}",
  ${v['protected'] == true ? "redirect: _privateGuard(authenticated)," : ""}
  pageBuilder: (context, state) => ${v['transition']}(
    name: state.name,
    key: state.pageKey,
    child: ${arguments.isEmpty ? "const" : ""} ${v['name']}(${arguments.join(", ")}),
  ),
  ${v["children"]?.isNotEmpty == true ? "routes: [${v["children"].map(buildRoute).join("\n")}]," : ""}
),
""";
  }

  @override
  generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) async {
    final generateForDir = annotation
        .read('generateForDir')
        .listValue
        .map((e) => e.toStringValue());

    final unauthenticatedPath =
        annotation.read('unauthenticatedPath').stringValue;

    final injectableConfigFiles = Glob("${generateForDir.first}/**.route.json");

    final jsonData = <Map>[];
    await for (final id in buildStep.findAssets(injectableConfigFiles)) {
      final json = jsonDecode(await buildStep.readAsString(id));
      if (json is List) {
        jsonData.addAll(json.cast<Map>());
        continue;
      }
      jsonData.add(json);
    }

    final paths = <List<String>>[];
    final urls = <List<String>>[];

    for (var e in jsonData) {
      Map element = e;
      final path = <String>[element['name']];
      final url = <String>[element['path']];

      while (element['on'] != null) {
        element = jsonData.firstWhere((e) => e['name'] == element['on']);
        path.add(element['name']);
        url.add(element['path']);
      }
      paths.add(path.reversed.toList());
      urls.add(url.reversed.toList());
    }

    final m = {};
    for (final a in paths) {
      tree(a, 0, m);
    }
    List<Map> result = record(m, jsonData);
    final routes = [];
    for (var path in paths) {
      final p = urls[paths.indexOf(path)].join('');

      String name = path.last
          .unCapitalize()
          .replaceAll(RegExp('page', caseSensitive: false), '');

      if (routes.where((r) => r["name"] == name).isNotEmpty) {
        String parent = path[path.length - 2]
            .replaceAll(RegExp('page', caseSensitive: false), '');
        name = '${parent.unCapitalize()}${name.capitalize()}';
      }

      routes.add({
        "path": p.replaceAll(RegExp("\\/+"), "/"),
        "name": name,
      });
    }

    final imports = <String>{
      "dart:async",
      "package:flutter/material.dart",
      "package:go_router/go_router.dart",
    };
    for (var e in jsonData) {
      imports.addAll([...e["imports"]]);
    }

    return """
${imports.map((import) => "import '$import';").join("\n")}

FutureOr<String?> Function(BuildContext, GoRouterState) _privateGuard(
        Future<bool> Function() authenticated) =>
  (context, state) async {
    final isAuthenticated = await authenticated();

    if (!isAuthenticated) return "$unauthenticatedPath";
    return null;
  };


enum Routes {
  ${routes.map((e) => '${e["name"]}("${e["path"]}")').join(",\n")};

  final String path;

  const Routes(this.path);

  Future<T?> push<T>(BuildContext context, {extra}) =>
      context.push<T>(path, extra: extra);

  void replace(BuildContext context, {extra}) =>
      context.replace(path, extra: extra);

   Uri get uri {
    return Uri.parse("//\$path");
  }

  Uri params(Map<String, String> params) {
    return uri.replace(
      pathSegments: uri.pathSegments.map((key) {
        return key.startsWith(":") ? params[key.substring(1)]! : key;
      }),
    );
  }
}

extension UriExtension on Uri {
  Future<T?> push<T>(BuildContext context, {extra}) {
    return context.push<T>(path, extra: extra);
  }
}

List<GoRoute>\$buildRoutes(Future<bool> Function() authenticated) => [
  ${result.map(buildRoute).join("\n")}
];
""";
  }
}

const TypeChecker _typeChecker = TypeChecker.fromRuntime(Routable);

class RouteGenerator extends Generator {
  Map<String, dynamic> _buildRoute(
      ClassElement clazz,
      DartObject routeAnnotation,
      List<LibraryElement> libs,
      List<String> imports) {
    final route = ConstantReader(routeAnnotation);
    final transition = route.peek('transition')?.typeValue;
    String? transitionName;
    if (transition?.element case final element?) {
      if (element is ClassElement) {
        final transitionLib = libs.firstWhere(
          (e) => e.exportNamespace.definedNames.values.contains(element),
        );
        imports.add(transitionLib.identifier);

        final superTypes = element.allSupertypes
            .map((e) => e.getDisplayString(withNullability: false));

        if (superTypes.where((type) => type.contains("Page")).isNotEmpty) {
          transitionName = element.displayName;
        } else {
          throw Exception(
            'Transition must be a subclass of Page',
          );
        }
      } else {
        throw Exception(
          'Transition must be a subclass of Page',
        );
      }
    }

    final extra = route.peek('extra')?.typeValue;

    if (extra?.element is ClassElement) {
      final extraLib = libs.firstWhere((e) =>
          e.exportNamespace.definedNames.values.contains(extra?.element));

      imports.add(extraLib.identifier);
    }

    return {
      'name': clazz.name,
      'path': route.read('path').stringValue,
      'protected': route.read('isProtected').boolValue,
      'force_params': route.read('useParams').boolValue,
      'use_query_params': route.read('useQueryParams').boolValue,
      'extra': route
          .peek('extra')
          ?.typeValue
          .getDisplayString(withNullability: false),
      'transition': transitionName ?? "MaterialPage",
      'on':
          route.peek('on')?.typeValue.getDisplayString(withNullability: false),
      'imports': imports,
    };
  }

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) async {
    for (var clazz in library.classes) {
      if (_typeChecker.hasAnnotationOfExact(clazz)) {
        final libs = await buildStep.resolver.libraries.toList();

        final imports = <String>[];

        final lib = libs.firstWhere(
            (e) => e.exportNamespace.definedNames.values.contains(clazz));

        imports.add(lib.identifier);

        final result = _typeChecker.annotationsOf(clazz).map((element) {
          return _buildRoute(clazz, element, libs, imports);
        });

        return jsonEncode(result.toList());
      }
    }
    return null;
  }
}

final RegExp _parameterRegExp = RegExp(r':(\w+)(\((?:\\.|[^\\()])+\))?');

String _escapeGroup(String group, [String? name]) {
  final String escapedGroup = group.replaceFirstMapped(
      RegExp(r'[:=!]'), (Match match) => '\\${match[0]}');
  if (name != null) {
    return '(?<$name>$escapedGroup)';
  }
  return escapedGroup;
}

RegExp patternToRegExp(String pattern, List<String> parameters) {
  final StringBuffer buffer = StringBuffer('^');
  int start = 0;
  for (final RegExpMatch match in _parameterRegExp.allMatches(pattern)) {
    if (match.start > start) {
      buffer.write(RegExp.escape(pattern.substring(start, match.start)));
    }
    final String name = match[1]!;
    final String? optionalPattern = match[2];
    final String regex = optionalPattern != null
        ? _escapeGroup(optionalPattern, name)
        : '(?<$name>[^/]+)';
    buffer.write(regex);
    parameters.add(name);
    start = match.end;
  }

  if (start < pattern.length) {
    buffer.write(RegExp.escape(pattern.substring(start)));
  }

  if (!pattern.endsWith('/')) {
    buffer.write(r'(?=/|$)');
  }
  return RegExp(buffer.toString(), caseSensitive: false);
}

Builder generateConfigMethods(BuilderOptions options) {
  // Step 1
  return LibraryBuilder(
    ConfigGenerator(),
    generatedExtension: '.routes.dart',
  );
}

Builder generateMethods(BuilderOptions options) {
  return LibraryBuilder(
    RouteGenerator(),
    formatOutput: (generated) => generated.replaceAll(RegExp(r'//.*|\s'), ''),
    generatedExtension: '.route.json',
  );
}
