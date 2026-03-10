# Vless-xHTTP-Argotunnel-Docker Deployment



This project provides a robust, containerized solution for deploying a VLESS-xHTTP node using the **Xray-core** kernel, exposed securely via Cloudflare Tunnel (Argo). It is designed for ease of deployment on PaaS platforms or self-hosted environments without requiring public IP addresses or open ports.

## Key Features

*   **High-Performance Kernel**: Utilizes `Xray-core` as the core for efficient and modern protocol handling.
*   **Secure Tunneling**: Integrates `cloudflared` to establish a secure tunnel to Cloudflare's edge network. No inbound ports need to be opened on the host machine.
*   **VLESS + xHTTP**: Uses the modern VLESS protocol over **xHTTP** transport, designed for better performance and evasion capabilities compared to traditional WebSocket.
*   **Automatic Configuration**:
    *   Generates a UUID automatically if one is not provided.
    *   Enforces a secure xHTTP path format `/{UUID}` to prevent unauthorized scanning.
*   **Client Link Generation**:
    *   Automatically generates ready-to-use VLESS links in the container logs upon startup.
    *   **New**: Includes a direct "Origin" node pointing to your Argo hostname.
    *   Links are pre-configured with known optimized Cloudflare domains (Best IPs) for better connectivity.
    *   **Fingerprint Randomization**: Automatically adds `fp=chrome` to simulate Chrome browser traffic.
    *   Generates a Base64-encoded subscription string aggregating all links for easy import into clients like v2rayN, sing-box (with Xray core), or Xray-core based clients.
*   **ECH Support**: Optional support for Encrypted Client Hello (ECH) to further enhance privacy and censorship resistance.
*   **IPv6 Edge Support**: Optional support for connecting to Cloudflare Edge via IPv6 (`EDGE_IP_VER=6`), useful in IPv4-restricted environments.
*   **PaaS Friendly**: Stateless design driven entirely by environment variables, making it suitable for platforms like Railway, Fly.io, or Heroku.
*   **Quick Tunnel Mode**: Supports temporary deployment using Cloudflare Quick Tunnels (trycloudflare.com) without a Cloudflare account.
*   **Automated Builds**: Includes a GitHub Actions workflow to automatically build and push the Docker image to the GitHub Container Registry.

## Architecture

1.  **Inbound**: The container runs `cloudflared`, which connects outbound to Cloudflare's edge network.
2.  **Routing**: Traffic destined for your public hostname is routed through the tunnel to the container.
3.  **Proxy**: `cloudflared` forwards the request to the local `Xray` instance running on `127.0.0.1:8080`.
4.  **Processing**: `Xray` handles the VLESS protocol over xHTTP, decapsulates the traffic, and forwards it to the target destination.

## Prerequisites

1.  **Cloudflare Account**: A domain name managed by Cloudflare (Required for stable deployment).
2.  **Cloudflare Tunnel**:
    *   Navigate to the Cloudflare Zero Trust Dashboard.
    *   Go to **Access** > **Tunnels** > **Create a Tunnel**.
    *   Select **Cloudflared** connector.
    *   Copy the **Token** from the installation command (the string following `--token`).
    *   **Public Hostname Configuration**:
        *   Add a public hostname (e.g., `vless.example.com`).
        *   Set **Service** to `HTTP` and **URL** to `localhost:8080`.
3.  **Enable gRPC**: Before deploying, ensure that **gRPC** is enabled in your Cloudflare dashboard for the domain you are using.
    *   Go to **Network** settings in Cloudflare Dashboard.
    *   Enable **gRPC**.

## Deployment

### Option 1: Docker Compose (Recommended)

1.  Create a `docker-compose.yml` file:

    ```yaml
    version: '3'
    services:
      vless-argo:
        image: ghcr.io/rating3pro/vless-xhttp-argotunnel-docker:latest
        container_name: vless-argo
        restart: always
        environment:
          - ARGO_TOKEN=eyJhIjoi...  # Paste your Cloudflare Tunnel Token here
          - PUBLIC_HOSTNAME=vless.example.com  # Your Tunnel Domain
          - ECH_CONFIG=true  # Optional: Enable ECH (Encrypted Client Hello)
          # - EDGE_IP_VER=6 # Optional: Use IPv6 for Argo Tunnel (Default: 4)
          # - UUID=...  # Optional: Fixed UUID
    ```

2.  Start the container:

    ```bash
    docker-compose up -d
    ```

### Option 2: Docker CLI

```bash
docker run -d \
  --name vless-argo \
  --restart always \
  -e ARGO_TOKEN="eyJhIjoi..." \
  -e PUBLIC_HOSTNAME="vless.example.com" \
  -e ECH_CONFIG="true" \
  -e EDGE_IP_VER="4" \
  ghcr.io/rating3pro/vless-xhttp-argotunnel-docker:latest
```

### Option 3: Quick Tunnel (No Account Required)

If you do not provide `ARGO_TOKEN` and `PUBLIC_HOSTNAME`, the container will automatically start a **Quick Tunnel** using `trycloudflare.com`.

```bash
docker run -d --name vless-quick ghcr.io/rating3pro/vless-xhttp-argotunnel-docker:latest
```

**⚠️ Quick Tunnel Limitations:**
*   **Unstable**: The URL (`*.trycloudflare.com`) changes every time the container restarts.
*   **Temporary**: Connections may drop or expire randomly.
*   **Not for Production**: Intended for testing or temporary usage only.
*   **Logs**: You must check `docker logs` to find the generated `trycloudflare.com` domain.

## Configuration

The application is configured entirely via environment variables.

| Variable | Required | Description | Default |
| :--- | :--- | :--- | :--- |
| `ARGO_TOKEN` | **No** | The Cloudflare Tunnel token. If missing, a Quick Tunnel is started. | None (Quick Tunnel) |
| `PUBLIC_HOSTNAME` | No | The public domain assigned to this tunnel. Required for generating share links in standard mode. Auto-detected in Quick Tunnel mode. | None |
| `UUID` | No | A specific VLESS User ID. If left empty, a random UUID will be generated at startup. | Randomly Generated |
| `ECH_CONFIG` | No | Set to `true` to enable default ECH, `false` to disable, or custom config string. | None (Disabled) |
| `EDGE_IP_VER` | No | Set to `6` to force Cloudflare Tunnel to connect via IPv6. Set to `4` or leave empty for default. | 4 |

**Note on xHTTP Path**: The xHTTP path is automatically set to `/{UUID}`. It cannot be manually configured. This ensures the path is unpredictable (security).

## Post-Deployment

After the container starts, check the logs to retrieve your connection details.

```bash
docker logs vless-argo
```

You will see output similar to the following:

```text
[INFO] ---------------------------------------------------
[INFO] Starting VLESS-xHTTP-ARGO Node (Xray-core)
[INFO] UUID: d4b717cd-e8d1-4875-af98-483ec8f0b204
[INFO] XHTTP Path: /d4b717cd-e8d1-4875-af98-483ec8f0b204
[INFO] PUBLIC_HOSTNAME: vless.example.com
[INFO] ---------------------------------------------------
...
[INFO] ---------------------------------------------------
[INFO] VLESS Share Links (Import to v2rayN / sing-box / Clash)
[INFO] ---------------------------------------------------
Server: vless.example.com (Origin)
vless://d4b717cd...@vless.example.com:443?encryption=none&security=tls&sni=vless.example.com&fp=chrome&type=xhttp&mode=auto&host=vless.example.com&path=%2Fd4b717cd...&alpn=h3%2Ch2%2Chttp%2F1.1#Argo-Origin

Server: cf.254301.xyz
vless://d4b717cd...@cf.254301.xyz:443?encryption=none&security=tls&sni=vless.example.com&fp=chrome&type=xhttp&mode=auto&host=vless.example.com&path=%2Fd4b717cd...&alpn=h3%2Ch2%2Chttp%2F1.1#cf.254301.xyz-Argo

...

[INFO] ---------------------------------------------------
[INFO] Base64 Subscription Link (Copy content below)
[INFO] ---------------------------------------------------
dmxlc3M6Ly8uLi4Kdmxlc3M6Ly8uLi4K...
[INFO] ---------------------------------------------------
```

*   **Individual Links**: Copy any of the `vless://` links to your client. They point to different "Best IP" domains but route to your tunnel.
*   **Subscription**: Copy the Base64 string and import it into your client (e.g., "Import from Clipboard") to add all nodes at once.

## Manual Client Configuration

If you prefer to configure your client manually, use the following settings:

*   **Server Address**: `cf.254301.xyz` (or any optimized Cloudflare IP/domain)
*   **Port**: `443`
*   **User ID (UUID)**: The UUID from the logs
*   **Encryption**: `none`
*   **Network (Transport)**: `xhttp`
*   **xHTTP Settings**:
    *   **Mode**: `auto`
    *   **Path**: `/{UUID}` (e.g., `/d4b717cd-e8d1-4875-af98-483ec8f0b204`)
    *   **Host**: Your public hostname (e.g., `vless.example.com`)
*   **TLS**: Enabled
*   **SNI**: Your public hostname (e.g., `vless.example.com`)
*   **Fingerprint (fp)**: `chrome`
*   **ALPN**: `h3,h2,http/1.1` (Recommended to include fallbacks)

## CI/CD

This repository contains a GitHub Actions workflow `.github/workflows/docker-image.yml`. It triggers on:

*   Push to the `main` branch.
*   Push of tags starting with `v` (e.g., `v1.0.0`).

The workflow builds the Docker image and pushes it to the GitHub Container Registry (ghcr.io) associated with the repository.

## Security & Optimization Details

*   **Zero Trust**: By using Cloudflare Tunnel, your server's IP remains hidden, and no ports are exposed to the internet.
*   **Path Security**: The xHTTP path is tied to the UUID, effectively acting as a secondary password.
*   **CDN Optimization**: The generated links use domains known to have better routing through Cloudflare's network for certain regions, potentially improving speed and stability.
*   **Keep-Alive**: The entrypoint script monitors both `Xray` and `cloudflared` processes and will terminate the container if either fails, allowing Docker's restart policy to handle recovery.
