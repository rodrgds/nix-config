FROM node:22-bookworm-slim@sha256:43ac6c60b8f89723f746e8a92ce91abd5017e627ce1ddfe4238355d3a30b772c AS node
FROM jellyfin/jellyfin:10.11.11@sha256:aefb67e6a7ff1debdd154a78a7bbb780fd0c873d8639210a7f6a2016ad2b35db
COPY --from=node /usr/local/bin/node /usr/local/bin/node
ENV PATH="/usr/lib/jellyfin-ffmpeg:/usr/local/bin:/usr/bin:/bin" NODE_ENV=production
WORKDIR /app
ENTRYPOINT ["node", "src/stream/main.js"]
