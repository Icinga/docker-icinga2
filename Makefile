IMAGE := icinga/icinga2:latest
BUILD_BASE := ubuntu:bionic

all: build

build:
	docker build --rm \
		--build-arg BUILD_BASE=$(BUILD_BASE) \
		--tag $(IMAGE) .
