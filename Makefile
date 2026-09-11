.PHONY: build deploy fmt

fmt:
	find lib -type f -name '*.dart' ! -name '*.g.dart' ! -name '*.freezed.dart' -exec dart format {} +

build:
	flutter build web

deploy: build
	wrangler deploy
