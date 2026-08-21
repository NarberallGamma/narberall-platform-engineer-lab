FROM apachesuperset.docker.scarf.sh/apache/superset:4.1.1

USER root

RUN apt update && apt install -y  firefox-esr wget bzip2 xvfb

RUN wget -qO- \
  https://github.com/mozilla/geckodriver/releases/latest/download/geckodriver-v0.36.0-linux64.tar.gz \
  | tar -xz -C /usr/local/bin

USER superset 
