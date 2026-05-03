# Build stage
FROM golang:1.22-alpine AS builder

ARG BUILD_DATE
ARG VCS_REF

WORKDIR /build

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-w -s" -o app ./cmd/server/

# Final minimal image
FROM gcr.io/distroless/static-debian12:nonroot

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
      org.opencontainers.image.revision="${VCS_REF}" \
      org.opencontainers.image.title="cse-pa-app" \
      org.opencontainers.image.vendor="ChinthanaHub"

COPY --from=builder /build/app /app

USER nonroot:nonroot

EXPOSE 8080 9090

ENTRYPOINT ["/app"]
