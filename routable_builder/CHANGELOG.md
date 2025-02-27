# ChangeLog

## 1.0.0

- **BREAKING CHANGE** 
  - `authenticated` parameter in `Routable` builder is now a `Future<bool> Function()` instead of `Future<bool>` to remove dependency on rebuilding `GoRouter`

## 0.2.0

- Add implementation for `useQueryParams` to `Routable` builder

## 0.1.1

- Update documentation

## 0.1.0

- initial release
