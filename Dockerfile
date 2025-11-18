FROM debian:12-slim

RUN apt-get update && \
    apt-get install -y ca-certificates curl unzip && \
    rm -rf /var/lib/apt/lists/*

# Psiphon
RUN mkdir -p /opt/psiphon && \
    curl -L https://github.com/Psiphon-Labs/psiphon-tunnel-core-binaries/raw/master/linux/psiphon-tunnel-core-x86_64 \
      -o /opt/psiphon/psiphon-tunnel-core-x86_64 && \
    chmod +x /opt/psiphon/psiphon-tunnel-core-x86_64

# Xray
RUN mkdir -p /tmp/xray && \
    curl -L https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip \
      -o /tmp/xray/xray.zip && \
    cd /tmp/xray && unzip xray.zip && \
    install xray /usr/local/bin/xray && \
    rm -rf /tmp/xray

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 21000/tcp

ENV PORT=21000
ENV UUID=""
ENV PUBLIC_HOST="CHANGE_ME"

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]