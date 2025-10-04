HOST=ghcr.io
REPOSITORY=$(HOST)/t089/jenkins-mcp
TAG=0.2.1

SWIFT_FLAGS=-Xlinker -s

docker: docker-manifest
	@echo "Docker images built successfully."

docker-arm64: 
	swift package --swift-sdk aarch64-swift-linux-musl \
		-c release ${SWIFT_FLAGS} --allow-network-connections=all \
		build-container-image \
		--from gcr.io/distroless/static-debian12:nonroot \
		--repository $(REPOSITORY):$(TAG)-arm64 \
		--product jenkins-mcp \
		--netrc-file .netrc

docker-amd64: 
	swift package --swift-sdk x86_64-swift-linux-musl \
		-c release ${SWIFT_FLAGS} --allow-network-connections=all \
		build-container-image \
		--from gcr.io/distroless/static-debian12:nonroot \
		--repository $(REPOSITORY):$(TAG)-amd64 \
		--product jenkins-mcp \
		--netrc-file .netrc

docker-manifest: docker-arm64 docker-amd64
	@echo "Creating Docker manifest..."
	docker manifest create $(REPOSITORY):$(TAG) \
		$(REPOSITORY):$(TAG)-amd64 \
		$(REPOSITORY):$(TAG)-arm64
	docker manifest push $(REPOSITORY):$(TAG)
	@echo "Docker manifest created and pushed successfully."

docker-latest:
	@echo "Creating latest multi-arch manifest from $(TAG)..."
	docker manifest create --amend $(REPOSITORY):latest \
		$(REPOSITORY):$(TAG)-amd64 \
		$(REPOSITORY):$(TAG)-arm64
	docker manifest push $(REPOSITORY):latest
	@echo "Latest multi-arch manifest created and pushed successfully."

.PHONY: docker docker-arm64 docker-amd64 docker-manifest docker-latest