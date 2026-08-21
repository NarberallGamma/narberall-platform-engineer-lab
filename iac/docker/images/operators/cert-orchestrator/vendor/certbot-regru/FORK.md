# Встраивание certbot-regru в cert-orchestrator

Исходный плагин: **certbot-regru** (Reg.ru DNS-01 для Certbot), MIT License, см. `LICENSE.txt`.

В этом каталоге — **вендорная копия** для автономной сборки образа `cert-orchestrator` без внешнего репозитория.

Отличия от апстрима:

- В `setup.py` отключена установка `regru.ini` в `/etc/letsencrypt` при `pip install`. В рантайме cert-orchestrator может сформировать INI из основного YAML (`letsencrypt.regru`) или использовать смонтированный файл по `regru_ini_path`.
- Пример учётных данных: `regru.ini.example`.

Обновление из апстрима: заменить файлы пакета `certbot_regru/` и при необходимости `setup.py`, сохраняя правки выше.
