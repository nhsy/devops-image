.PHONY: all full

all:
	# docker buildx build --pull --force-rm --no-cache --tag gcp-devops --load .
	docker build --tag gcp-devops .

full:
	docker build --pull --force-rm --no-cache --tag gcp-devops .
	