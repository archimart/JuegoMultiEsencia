# ── Stage 1: Instalar Godot y exportar el servidor ───────────────
FROM ubuntu:22.04 AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    wget unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN wget -q "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_linux.x86_64.zip" -O /tmp/godot.zip \
    && unzip -q /tmp/godot.zip -d /tmp \
    && mv "/tmp/Godot_v4.6.2-stable_linux.x86_64" /usr/local/bin/godot \
    && chmod +x /usr/local/bin/godot \
    && rm /tmp/godot.zip

RUN mkdir -p /root/.local/share/godot/export_templates/4.6.2.stable \
    && wget -q "https://github.com/godotengine/godot/releases/download/4.6.2-stable/Godot_v4.6.2-stable_export_templates.tpz" -O /tmp/templates.tpz \
    && unzip -q /tmp/templates.tpz -d /tmp/tpl \
    && mv /tmp/tpl/templates/* /root/.local/share/godot/export_templates/4.6.2.stable/ \
    && rm -rf /tmp/templates.tpz /tmp/tpl

WORKDIR /project
COPY . .
RUN mkdir -p /build/server \
    && godot --headless --export-release "Linux Server" /build/server/game.x86_64

# ── Stage 2: Imagen final ligera con solo el binario ─────────────
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /build/server/game.x86_64 .
RUN chmod +x game.x86_64

EXPOSE 7777/udp
CMD ["./game.x86_64", "--headless", "--", "--server"]
