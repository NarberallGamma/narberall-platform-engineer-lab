# ansible-runner — ansible-playbook in a container (tag 1.1).
# jmespath — json_query (inbound-summary and similar filters).
FROM alpine:3.20

RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2 \
    openssh-client \
    sshpass \
    && pip3 install --break-system-packages --no-cache-dir \
      ansible-core \
      passlib \
      jmespath

ENV ANSIBLE_COLLECTIONS_PATH=/usr/share/ansible/collections

COPY requirements.yml /tmp/requirements.yml
RUN ansible-galaxy collection install -r /tmp/requirements.yml --force -p "${ANSIBLE_COLLECTIONS_PATH}" \
    && rm /tmp/requirements.yml

WORKDIR /work
