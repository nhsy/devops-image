.PHONY: local push all

local:
	docker buildx build --pull --force-rm --no-cache --tag gcp-devops --load .

push:
	docker buildx build --pull --force-rm --tag dizzyplan/gcp-devops --tag gcp-devops --platform=linux/arm64,linux/amd64 --push .

all: local push