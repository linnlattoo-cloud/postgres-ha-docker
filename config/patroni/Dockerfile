FROM postgres:17-bookworm

LABEL maintainer="Linn Latt Oo"
LABEL description="PostgreSQL 17 HA Node managed by Patroni and etcd3"

ENV DEBIAN_FRONTEND=noninteractive

# Install runtime dependencies and Python packages for Patroni
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-psycopg2 \
    python3-yaml \
    curl \
    jq \
    iproute2 \
    procps \
    gosu \
    && pip install --no-cache-dir --break-system-packages "patroni[etcd3]>=3.3.0" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create Patroni configuration and data directory
RUN mkdir -p /etc/patroni /var/lib/postgresql/data \
    && chown -R postgres:postgres /etc/patroni /var/lib/postgresql

COPY patroni.yml /etc/patroni/patroni.yml.template
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

EXPOSE 5432 8008

ENTRYPOINT ["/entrypoint.sh"]
