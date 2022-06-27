.PHONY: all

all:
	# docker buildx build --pull --force-rm --no-cache --tag gcp-devops --load .
	docker build --pull --force-rm --no-cache --tag gcp-devops .
