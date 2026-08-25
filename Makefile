.PHONY: build deploy

build:
	flutter build web

deploy: build
	wrangler deploy
