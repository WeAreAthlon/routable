# Routable

Routable is a Dart/Flutter package that provides code generation for routing in Flutter applications. It uses annotations to define routes and generates the necessary code to handle navigation.

This package uses [go_router](https://pub.dev/packages/go_router) package and aims to simplify the process of defining routes in Flutter applications.

## Features

- Define routes using annotations
- Generate route configurations automatically
- Supports nested routes
- Supports route parameters
- Customizable route transitions
- Guards for protected routes

## Installation

Add the following to your `pubspec.yaml` file:

```yaml
dependencies:
  go_router:
  routable_annotations:
dev_dependencies:
  build_runner:
  routable_builder:
```

## Usage

1. Define your routes using the @Routable annotation:

```dart
import 'package:routable_annotations/routable_annotations.dart';

@Routable(path: '/home')
class HomePage extends StatelessWidget {
  // ...
}

@Routable(path: '/login')
class LoginPage extends StatelessWidget {
  // ...
}
```

2. Run the build_runner to generate the route configurations:

```bash
flutter pub run build_runner build
```

3. Use the generated routes in your main.dart file:

```dart
import 'package:go_router/go_router.dart';
import 'generated_routes.dart';

void main() {
  final router = GoRouter(
    routes: $buildRoutes(),
  );

  runApp(MyApp(router: router));
}
```

4. For navigation, the generated routes can be used as follows:

```dart
Routes.home.push(context);
```

Routes enum is generated with additional methods for navigation:

```dart
Routes.home.push(context);
Routes.home.push(context, extra);
Routes.home.replace(context);
Routes.home.replace(context, extra);

//Routes.product  `/product/:id` // Route with parameter
Routes.product.params({"id": "item_id"}).push(context); // this will navigate to `/product/item_id`
```

5. Routes can be nested and protected by using the `@Routable` annotation on a class field:

```dart
@Routable(path: '/home', isProtected: true) // Protected route will redirect to /login (by default) if not authenticated
class HomePage extends StatelessWidget {
 // ...
}

@Routable(path: '/profile' on: HomePage) // Nested route under HomePage will be /home/profile
class ProfilePage extends StatelessWidget {
 // ...
}
```

6. Add protected routes by providing a guard function:

```dart
import 'package:go_router/go_router.dart';
import 'generated_routes.dart';

Future<bool> authenticationGuard() async {
  // Check if user is authenticated
  return true;
}

void main() {
  final router = GoRouter(
    routes: $buildRoutes(authenticationGuard()),
  );

  runApp(MyApp(router: router));
}
```

Currently, the package only supports a single guard function for all protected routes.

Additional options can be provided to the `@Routable` annotation:

```dart
//Custom transition
@Routable(path: '/home', transition: NoTransitionPage)
class HomePage extends StatelessWidget {
  // ...
}

//Read url params from nested route

@Routable(path: '/product/:id')
class ProductPage extends StatelessWidget {
  // ...
}
//Adding useParams to nested route will read url params from parent route so they can be used in nested route
@Routable(path: '/edit', on: ProductPage, useParams: true)
class EditProductPage extends StatelessWidget {
  final String? id;
  // ...
}


//Extra data
@Routable(path: '/product/:id', extra: Product)
class ProductPage extends StatelessWidget {
  final Product? params;
  // ...
}
//Extra data can be passed to the route using extra parameter
Routes.product.push(context, Product(id: 'item_id'));
```

```dart
@Routable(path: '/search', useQueryParams: true)
class SearchPage extends StatelessWidget {
  final Map<String, String>? queryParams;

  SearchPage({this.queryParams});

  ...
}

// Generated GoRoute for SearchPage
GoRoute(
  path: '/search',
  pageBuilder: (context, state) => MaterialPage(
    child: SearchPage(queryParams: state.uri.queryParameters),
  ),
),
```


## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## Acknowledgements

- [source_gen](https://pub.dev/packages/source_gen)
- [build_runner](https://pub.dev/packages/build_runner)
- [go_router](https://pub.dev/packages/go_router)

## Contact

For any questions or suggestions, please contact us at support@weareathlon.com.
