library routable_annotations;

class Routable {
  final String path;
  final Type? on;
  final bool isProtected;
  final Type? extra;
  final Type? transition;
  final bool useParams;
  final bool useQueryParams;
  const Routable({
    required this.path,
    this.on,
    this.extra,
    this.useParams = false,
    this.isProtected = false,
    this.transition,
    this.useQueryParams = false,
  });
}

class RouteConfig {
  final String unauthenticatedPath;
  final List<String> generateForDir;

  const RouteConfig({
    this.unauthenticatedPath = '/login',
    this.generateForDir = const ['lib'],
  });
}
