FROM openjdk:8-jre-alpine3.9

# ===============
# Alpine packages
# ===============

RUN apk update \
    && apk add --no-cache openssl py-pip \
    && apk add --no-cache --virtual build-deps wget git

# =============
# oxAuth client
# =============

# JAR files required to generate OpenID Connect keys
ENV GLUU_VERSION=4.1.0.Final \
    GLUU_BUILD_DATE="2020-02-28 15:42"

RUN mkdir -p /app/javalibs \
    && wget -q https://ox.gluu.org/maven/org/gluu/oxauth-client/${GLUU_VERSION}/oxauth-client-${GLUU_VERSION}-jar-with-dependencies.jar -O /app/javalibs/oxauth-client.jar

# =================
# Shibboleth sealer
# =================

RUN mkdir -p /app/javalibs \
    && wget -q https://build.shibboleth.net/nexus/content/repositories/releases/net/shibboleth/utilities/java-support/7.5.1/java-support-7.5.1.jar -O /app/javalibs/java-support.jar \
    && wget -q https://repo1.maven.org/maven2/com/beust/jcommander/1.48/jcommander-1.48.jar -O /app/javalibs/jcommander.jar \
    && wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-api/1.7.26/slf4j-api-1.7.26.jar -O /app/javalibs/slf4j-api.jar \
    && wget -q https://repo1.maven.org/maven2/org/slf4j/slf4j-simple/1.7.26/slf4j-simple-1.7.26.jar -O /app/javalibs/slf4j-simple.jar

# ====
# Tini
# ====

RUN wget -q https://github.com/krallin/tini/releases/download/v0.18.0/tini-static -O /usr/bin/tini \
    && chmod +x /usr/bin/tini

# ======
# Python
# ======

COPY requirements.txt /tmp/
RUN pip install --no-cache-dir -U pip \
    && pip install --no-cache-dir -r /tmp/requirements.txt

# =======
# Cleanup
# =======

RUN apk del build-deps \
    && rm -rf /var/cache/apk/*

# =======
# License
# =======

RUN mkdir -p /licenses
COPY LICENSE /licenses/

# ==========
# Config ENV
# ==========

ENV GLUU_CONFIG_ADAPTER=consul \
    GLUU_CONFIG_CONSUL_HOST=localhost \
    GLUU_CONFIG_CONSUL_PORT=8500 \
    GLUU_CONFIG_CONSUL_CONSISTENCY=default \
    GLUU_CONFIG_CONSUL_SCHEME=http \
    GLUU_CONFIG_CONSUL_VERIFY=false \
    GLUU_CONFIG_CONSUL_CACERT_FILE=/etc/certs/consul_ca.crt \
    GLUU_CONFIG_CONSUL_CERT_FILE=/etc/certs/consul_client.crt \
    GLUU_CONFIG_CONSUL_KEY_FILE=/etc/certs/consul_client.key \
    GLUU_CONFIG_CONSUL_TOKEN_FILE=/etc/certs/consul_token \
    GLUU_CONFIG_KUBERNETES_NAMESPACE=default \
    GLUU_CONFIG_KUBERNETES_CONFIGMAP=gluu \
    GLUU_CONFIG_KUBERNETES_USE_KUBE_CONFIG=false

# ==========
# Secret ENV
# ==========

ENV GLUU_SECRET_ADAPTER=vault \
    GLUU_SECRET_VAULT_SCHEME=http \
    GLUU_SECRET_VAULT_HOST=localhost \
    GLUU_SECRET_VAULT_PORT=8200 \
    GLUU_SECRET_VAULT_VERIFY=false \
    GLUU_SECRET_VAULT_ROLE_ID_FILE=/etc/certs/vault_role_id \
    GLUU_SECRET_VAULT_SECRET_ID_FILE=/etc/certs/vault_secret_id \
    GLUU_SECRET_VAULT_CERT_FILE=/etc/certs/vault_client.crt \
    GLUU_SECRET_VAULT_KEY_FILE=/etc/certs/vault_client.key \
    GLUU_SECRET_VAULT_CACERT_FILE=/etc/certs/vault_ca.crt \
    GLUU_SECRET_KUBERNETES_NAMESPACE=default \
    GLUU_SECRET_KUBERNETES_SECRET=gluu \
    GLUU_SECRET_KUBERNETES_USE_KUBE_CONFIG=false

# ===========
# Generic ENV
# ===========

ENV GLUU_WAIT_MAX_TIME=300 \
    GLUU_WAIT_SLEEP_DURATION=10

# ====
# misc
# ====

LABEL name="Certman" \
    maintainer="Gluu Inc. <support@gluu.org>" \
    vendor="Gluu Federation" \
    version="4.1.0" \
    release="dev" \
    summary="Gluu Certman" \
    description="Manage certs and crypto keys for Gluu Server"

COPY scripts /app/scripts

RUN mkdir -p /etc/certs \
    && chmod +x /app/scripts/entrypoint.sh

# # create gluu user
# RUN useradd -ms /bin/sh --uid 1000 gluu \
#     && usermod -a -G root gluu

# # adjust ownership
# RUN chown -R 1000:1000 /app \
#     && chgrp -R 0 /app && chmod -R g=u /app \
#     && chgrp -R 0 /etc/certs && chmod -R g=u /etc/certs

# # run the entrypoint as gluu user
# USER 1000

ENTRYPOINT ["tini", "-g", "--", "sh", "/app/scripts/entrypoint.sh"]
CMD ["--help"]