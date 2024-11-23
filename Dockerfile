ARG ALPINE_VERSION=3.20
ARG GOLANG_VERSION=1.23.2

FROM --platform=${BUILDPLATFORM:-linux/amd64} golang:${GOLANG_VERSION}-alpine${ALPINE_VERSION} as builder

RUN apk add --update --no-cache git

RUN git clone --depth 1 --branch light-handler https://github.com/vnxme/swgp-go /app

WORKDIR /app/cmd/swgp-go

ARG TARGETARCH TARGETOS

RUN \
  --mount=type=cache,target=/root/.cache/go-build \
  --mount=type=cache,target=/go/pkg \
  CGO_ENABLED=0 GOOS=${TARGETOS} GOARCH=${TARGETARCH} \
  go build -ldflags="-w -s" -o /usr/bin/swgp-go main.go


FROM --platform=${TARGETPLATFORM:-linux/amd64} alpine:${ALPINE_VERSION}

COPY --from=builder /app/docs/config.json /etc/swgp-go/config.json
COPY --from=builder /usr/bin/swgp-go /usr/bin/

RUN chmod +x /usr/bin/swgp-go

CMD ["/usr/bin/swgp-go", "-confPath", "/etc/swgp-go/config.json", "-logLevel", "info"]
