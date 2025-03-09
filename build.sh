export BUILDKIT_STEP_LOG_MAX_SIZE=20485760;
export DOCKER_BUILDKIT=1;
docker buildx build \
--platform=linux/arm64 \
--progress=plain \
--build-arg BUILDKIT_STEP_LOG_MAX_SIZE=20485760 \
-t dustyarmstrong/alpine-xoa:armv8 \
.
