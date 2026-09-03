# LightningEver RTL — Docker image.
#
# This branch ships the Angular frontend pre-built in ./frontend and the
# TypeScript backend pre-compiled in ./backend, so we only need to install
# the *production* dependencies for rtl.js to run. That keeps the image
# small (~250 MB) and the build fast.
#
# At runtime, mount your own RTL-Config.json at /RTL/RTL-Config.json:
#   docker run -p 3008:3008 \
#     -v /etc/lightningever/RTL-Config.json:/RTL/RTL-Config.json:ro \
#     silverruler/lightningever-rtl:260530

ARG BASE_DISTRO="node:22-alpine"

FROM ${BASE_DISTRO} AS builder
WORKDIR /RTL
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --legacy-peer-deps --no-audit --no-fund
COPY rtl.js ./rtl.js
COPY frontend ./frontend
COPY backend ./backend

FROM ${BASE_DISTRO} AS runner
RUN apk add --no-cache tini
WORKDIR /RTL

COPY --from=builder /RTL/rtl.js ./rtl.js
COPY --from=builder /RTL/package.json ./package.json
COPY --from=builder /RTL/frontend ./frontend
COPY --from=builder /RTL/backend ./backend
COPY --from=builder /RTL/node_modules ./node_modules

ENV NODE_ENV=production

EXPOSE 3008

ENTRYPOINT ["/sbin/tini", "-g", "--"]
CMD ["node", "rtl"]
