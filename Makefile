.PHONY: all aws gcp

all: aws gcp
	
aws:
	docker build --pull --force-rm --no-cache --tag aws-devops --target aws-devops .

gcp:
	docker build --pull --force-rm --no-cache --tag gcp-devops --target gcp-devops .
