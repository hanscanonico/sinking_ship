# syntax=docker/dockerfile:1
#
# The game for the mini PC (SH12), built from this checkout: the export stage runs
# the repo's own exports (`make export-server export-web`) on Godot's Linux editor,
# and each runtime stage takes one of them.
#   --target server   the dedicated server: the exported Linux binary, as a non-root
#                     user, with no shell or package manager in the image
#   --target web      the browser build, as static files behind nginx
# deploy/compose.yml builds both, with the repository root as the context
# (Dockerfile.dockerignore beside this file keeps the context small).
#
# Untested: written on a machine without Docker. deploy/README.md says what to check
# on the first build.

ARG GODOT_VERSION=4.7.1-stable

FROM debian:bookworm-slim AS export
ARG GODOT_VERSION
# The SHA-512 of the editor's zip and of the export templates, as the release's
# SHA512-SUMS.txt lists them: required, so a download is never trusted unchecked.
ARG GODOT_EDITOR_SHA512
ARG GODOT_TEMPLATES_SHA512
# The editor links these even headless, as CI's verify job installs them.
RUN apt-get update \
	&& apt-get install -y --no-install-recommends ca-certificates curl unzip make \
		libgl1 libx11-6 libxcursor1 libxinerama1 libxi6 libxrandr2 \
	&& rm -rf /var/lib/apt/lists/*
# Only the two templates the exports use are kept: the Linux server's and the
# single-threaded web build's.
RUN set -eu; \
	: "${GODOT_EDITOR_SHA512:?}" "${GODOT_TEMPLATES_SHA512:?}"; \
	release="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}"; \
	curl -fsSL -o /tmp/godot.zip "$release/Godot_v${GODOT_VERSION}_linux.x86_64.zip"; \
	echo "$GODOT_EDITOR_SHA512  /tmp/godot.zip" | sha512sum -c -; \
	unzip -q /tmp/godot.zip -d /tmp/godot; \
	mv "/tmp/godot/Godot_v${GODOT_VERSION}_linux.x86_64" /usr/local/bin/godot; \
	curl -fsSL -o /tmp/templates.tpz "$release/Godot_v${GODOT_VERSION}_export_templates.tpz"; \
	echo "$GODOT_TEMPLATES_SHA512  /tmp/templates.tpz" | sha512sum -c -; \
	unzip -q /tmp/templates.tpz -d /tmp/templates; \
	installed="/root/.local/share/godot/export_templates/$(echo "$GODOT_VERSION" | tr - .)"; \
	mkdir -p "$installed"; \
	for template in version.txt linux_release.x86_64 web_nothreads_release.zip; do \
		mv "/tmp/templates/templates/$template" "$installed/"; \
	done; \
	rm -rf /tmp/godot /tmp/godot.zip /tmp/templates /tmp/templates.tpz
WORKDIR /src
COPY . .
RUN make import && make export-server export-web


FROM gcr.io/distroless/base-debian12:nonroot AS server
COPY --from=export /src/build/server/ /app/
# Godot keeps its user:// data and its log file under these: the tmpfs compose mounts,
# the root filesystem being read-only.
ENV XDG_DATA_HOME=/tmp XDG_CONFIG_HOME=/tmp XDG_CACHE_HOME=/tmp
USER nonroot
# ServerRules' port; nothing publishes it — the proxy reaches it on the game network.
EXPOSE 47923
ENTRYPOINT ["/app/sinking_ship_server.x86_64", "--headless", "--"]
# Every address of the container, as only the game network reaches it.
CMD ["--server", "--bind=0.0.0.0"]


FROM nginxinc/nginx-unprivileged:1.27-alpine AS web
COPY deploy/web.conf /etc/nginx/conf.d/default.conf
COPY --from=export /src/build/web/ /usr/share/nginx/html/
