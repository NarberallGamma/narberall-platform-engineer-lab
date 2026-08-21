# Image for running Ansible playbooks (prepare_servers, Vault, db_restore, node-exporter, bootstrap users).
# Alpine + pinned ansible-core 2.16.x and Galaxy collections. Not creator-ee.
FROM alpine:3.20

RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2 \
    openssh-client \
    sshpass \
    && pip3 install --break-system-packages --no-cache-dir 'ansible-core>=2.16.0,<2.17.0'

# Install hvac for community.hashi_vault (Vault playbooks).
RUN pip3 install --break-system-packages --no-cache-dir hvac

ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml --force -p "${ANSIBLE_COLLECTIONS_PATH}" \
    && rm /tmp/requirements.yml

WORKDIR /work
