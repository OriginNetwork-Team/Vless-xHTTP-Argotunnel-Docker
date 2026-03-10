FROM alpine:latest

# Install dependencies
RUN apk add --no-cache ca-certificates tzdata

# Copy sing-box
COPY --from=ghcr.io/sagernet/sing-box:latest /usr/local/bin/sing-box /usr/local/bin/sing-box

# Copy cloudflared
COPY --from=cloudflare/cloudflared:latest /usr/local/bin/cloudflared /usr/local/bin/cloudflared

# Setup workspace
WORKDIR /app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Environment variables
ENV UUID=
ENV ARGO_TOKEN=
ENV PUBLIC_HOSTNAME=

# Entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
