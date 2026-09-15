.PHONY: build deploy fmt preview run

fmt:
	find lib -type f -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' -exec dart format {} +

run:
	flutter run -d chrome

run-release:
	flutter run --release -d chrome

preview:
	flutter widget-preview start

build:
	flutter build web

deploy: build
	wrangler deploy
