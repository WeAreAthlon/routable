library routable_annotations;

/// Annotation used to mark a class or widget as a route.
///
/// The [Routable] annotation provides metadata for code generation
/// of routes. It is not executed at runtime but instead guides
/// the route builder when scanning your codebase.
///
/// Example:
/// ```dart
/// @Routable(
///   path: '/profile/:id',
///   isProtected: true,
///   useParams: true,
/// )
/// class ProfileRoute {}
/// ```
class Routable {
  /// The URL path for this route (e.g., `/home`, `/users/:id`).
  final String path;

  /// The target type (usually a widget class) that this route
  /// is children to.
  final Type? on;

  /// Marks this route as requiring authentication.
  ///
  /// If `true`, the generator will ensure unauthenticated users
  /// are redirected to [RouteConfig.unauthenticatedPath].
  final bool isProtected;

  /// Optional "extra" type to indicate additional arguments
  /// that can be passed to the route.
  final Type? extra;

  /// Optional transition type to be used for this route
  /// (e.g., a custom page transition).
  final Type? transition;

  /// Whether to enable path parameter parsing.
  ///
  /// Example: `/users/:id` will expose the `id` parameter
  /// when [useParams] is `true`.
  final bool useParams;

  /// Whether to enable query parameter parsing.
  ///
  /// Example: `/search?term=flutter` exposes `term`
  /// when [useQueryParams] is `true`.
  final bool useQueryParams;

  /// Creates a new [Routable] annotation.
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

/// Annotation used to configure global routing behavior.
///
/// The [RouteConfig] annotation is typically placed on a
/// top-level file or entry point to specify defaults for
/// the route generator.
///
/// Example:
/// ```dart
/// @RouteConfig(
///   unauthenticatedPath: '/login',
///   generateForDir: ['lib/features'],
/// )
/// Raw<GoRouter> app_routes() {...};
/// ```
class RouteConfig {
  /// Path where unauthenticated users should be redirected.
  ///
  /// Defaults to `/login`.
  final String unauthenticatedPath;

  /// Directories that should be scanned for `@Routable` annotations.
  ///
  /// Defaults to `['lib']`.
  final List<String> generateForDir;

  /// Creates a new [RouteConfig] annotation.
  const RouteConfig({
    this.unauthenticatedPath = '/login',
    this.generateForDir = const ['lib'],
  });
}
