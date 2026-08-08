# Widget gallery

Run the dev-only gallery in Chrome:

```sh
flutter run -d chrome -t dev/widget_gallery/main.dart
```

Verify its web build:

```sh
flutter build web -t dev/widget_gallery/main.dart
```

Production continues to use `lib/main.dart` and does not import this folder.
