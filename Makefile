.PHONY: build manifest buildfat check run debug push save clean clobber

REPO    = fredblgr/
NAMEX   = docker-3asem-x11
#ARCH    = `uname -m`
TAG     = 2021
ARCH   := $$(arch=$$(uname -m); if [[ $$arch == "x86_64" ]]; then echo amd64; else echo $$arch; fi)
ARCHS   = amd64 arm64
IMAGESX:= $(ARCHS:%=$(REPO)$(NAMEX):$(TAG)-%)
PLATFORMS := $$(first="True"; for a in $(ARCHS); do if [[ $$first == "True" ]]; then printf "linux/%s" $$a; first="False"; else printf ",linux/%s" $$a; fi; done)
# Temporarily do  not tag the image with its architecture.
# We know how to build only on x86_64
#ARCHIMAGEX := $(REPO)$(NAMEX):$(TAG)-$(ARCH)
ARCHIMAGEX := $(REPO)$(NAMEX):$(TAG)

help:
	@echo "# Available targets:"
	@echo "#   - build: build docker image"
	@echo "#   - clean: clean docker build cache"
	@echo "#   - run: run docker container"
	@echo "#   - push: push docker image to docker hub"

resources/why3.tar: resources/why3/*
	tar cvCf resources/why3 resources/why3.tar --exclude .DS_Store .

resources/dot_isabelle_2021.tar: resources/dot_isabelle_2021/*
	tar cvCf resources/dot_isabelle_2021 resources/dot_isabelle_2021.tar --exclude .DS_Store .

# Build image
build: resources/why3.tar resources/dot_isabelle_2021.tar
	docker build --build-arg arch=$(ARCH) --tag $(ARCHIMAGEX) .
	@danglingimages=$$(docker images --filter "dangling=true" -q); \
	if [[ $$danglingimages != "" ]]; then \
	  docker rmi $$(docker images --filter "dangling=true" -q); \
	fi

# Safe way to build multiarchitecture images:
# - build each image on the matching hardware, with the -$(ARCH) tag
# - push the architecture specific images to Dockerhub
# - build a manifest list referencing those images
# - push the manifest list so that the multiarchitecture image exist
manifest:
	docker manifest create $(REPO)$(NAMEX):$(TAG) $(IMAGESX)
	@for arch in $(ARCHS); \
	 do \
	   echo docker manifest annotate --os linux --arch $$arch $(REPO)$(NAMEX):$(TAG) $(REPO)$(NAMEX):$(TAG)-$$arch; \
	   docker manifest annotate --os linux --arch $$arch $(REPO)$(NAMEX):$(TAG) $(REPO)$(NAMEX):$(TAG)-$$arch; \
	 done
	docker manifest push $(REPO)$(NAMEX):$(TAG)

rmmanifest:
	docker manifest rm $(REPO)$(NAMEX):$(TAG)

# Create new builder supporting multi architecture images
newbuilder:
	docker buildx create --name newbuilder
	docker buildx use newbuilder

# Hasardous way to build multiarchitecture images:
# - use buildx to try to build the different images using qemu for foreign architectures
# This fails with some images because of the emulation of foreign architectures
# --load with multiarch image fails (2021-02-15), use --push instead
buildfat:
	docker buildx build --push \
	  --platform $(PLATFORMS) \
	  --build-arg arch=$(ARCH) \
	  --tag $(REPO)$(NAME):$(TAG) .
	@danglingimages=$$(docker images --filter "dangling=true" -q); \
	if [[ $$danglingimages != "" ]]; then \
	  docker rmi $$(docker images --filter "dangling=true" -q); \
	fi

push:
	docker push $(ARCHIMAGEX)

save:
	docker save $(ARCHIMAGE) | gzip > $(NAME)-$(TAG)-$(ARCH).tar.gz

# Clear caches
clean:
	docker builder prune

clobber:
	docker rmi $(REPO)$(NAME):$(TAG) $(ARCHIMAGE)
	docker rmi $(REPO)$(NAMEX):$(TAG) $(ARCHIMAGEX)
	docker builder prune --all

run:
	docker run --rm --tty --interactive \
		--env USERNAME="`id -n -u`" --env USERID="`id -u`" \
		--volume ${PWD}:/workspace:rw \
		--workdir /workspace \
		--env DISPLAY="host.docker.internal:0" \
		--name $(NAMEX) \
		$(ARCHIMAGEX)

runasroot:
	docker run --rm --tty --interactive \
		--volume ${PWD}:/workspace:rw \
		--workdir /workspace \
		--env DISPLAY="host.docker.internal:0" \
		--name $(NAMEX) \
		$(ARCHIMAGEX)
