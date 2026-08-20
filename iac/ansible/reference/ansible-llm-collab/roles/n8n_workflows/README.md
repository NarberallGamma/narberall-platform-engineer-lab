# Роль n8n_workflows

Синхронизация воркфлоу n8n из репозитория (GitOps): загрузка JSON из `files/workflows/*.json` и создание/обновление воркфлоу в n8n через REST API.

## Nextcloud Groupfolders: два воркфлоу (form + webhook)

- **Форма** (`nextcloud_groupfolders_form.json`): `formPath` → URL вида `{n8n_base}/form/nextcloud-groupfolders`. Поля: **Profile** (обязательно: `nextcloud-dev` или `regul`), **Client name** (для режимов по одному клиенту), чекбоксы **переиграть всем клиентам** (`--all-clients`) и **только ACL одному без MKCOL** (`--permissions-only`). Если отмечены оба чекбокса, режим трактуется как «всем клиентам» (как более широкий сценарий); лучше оставить один режим или оба выключены = стандартный прогон с MKCOL одному клиенту.
- **API** (`nextcloud_groupfolders_webhook.json`): в ноде Webhook задано `path: nextcloud-groupfolders-api` → POST на `{n8n_base}/webhook/.../nextcloud-groupfolders-api` с JSON-телом. Те же поля, что в форме (`profile`, необязательно `host`/`limit` если без `profile` — как `--limit`), `client_name`, опционально `reapply_all_clients` и `permissions_only` (логические). Команда на контрол-ноду строится в ноде **Execute a command**: `sudo -u ansible /ansible/scripts/run/run_nextcloud_groupfolders.sh …` см. скрипт `ansible/scripts/run/run_nextcloud_groupfolders.sh`. Значение `path` **не** должно совпадать с `formPath`: иначе при активации второго воркфлоу n8n выдаёт **Conflicting Webhook Path** (оба триггера бронируют один сегмент под `/webhook/`).
- В **(Form)** в JSON только **On form submission** и **Execute a command**; нод Webhook / Respond to Webhook там нет (они в воркфлоу **(Webhook)**). Если в UI остались старые ноды — выполнить синхронизацию плейбука ещё раз; граф в n8n должен совпадать с репозиторием после PUT.

## Требования

- Роль **n8n_init** выполняется до этой (API key из Vault).
- В `group_vars/n8n_workflows.yml`: `n8n_base_url`, `n8n_workflows_to_sync`.
- В n8n после первого деплоя при необходимости привязать credentials вручную:
  - **SSH Ansible Host** — в ноде «Execute a command» (подключение к контрол-ноде Ansible).
  - **Аутентификация Webhook** — в JSON репозитория задано `headerAuth`; при желании можно переключить на JWT/other в UI n8n и привязать credential к ноде Webhook.

## Webhook: ответ (stdout/stderr)

- В воркфлоу webhook в репозитории нода **Respond to Webhook** возвращает HTML с результатом.
- Ответ webhook и формы формирует нода **Respond to Webhook**: в браузер возвращается HTML с полем вывода команды (stdout), ошибками (stderr), кодом выхода и подсказкой, где смотреть полный лог: на контрол-ноде Ansible в `/ansible/artifacts/logs` и в интерфейсе n8n (Executions).
- Вывод доступен **после завершения** команды: нода Execute Command в n8n не отдаёт stdout/stderr по мере выполнения (стриминг в реальном времени средствами n8n недоступен). Для «живого» просмотра лога во время выполнения: на контрол-ноде выполнить `tail -f /ansible/artifacts/logs/<файл_лога>.log` или открыть выполнение в n8n → Executions после старта и смотреть вывод по мере появления (если интерфейс обновляет данные).

## Форма: аутентификация

Form Trigger поддерживает Basic Authentication. В JSON по умолчанию аутентификация не включена. Чтобы включить: в n8n в ноде «On form submission» выбрать Authentication → Basic Auth и привязать созданный credential. Либо добавить в форму скрытое поле (например секретный ключ) и проверять его в отдельной ноде перед Execute command.

## Добавление новых воркфлоу

1. Положить JSON в `roles/n8n_workflows/files/workflows/<имя>.json` (без полей `id`, `createdAt`, `updatedAt` в корне).
2. Добавить `<имя>` в список `n8n_workflows_to_sync` в `group_vars/n8n_workflows.yml`.
3. Запустить плейбук `playbooks/n8n_workflows.yml`.

Воркфлоу в n8n ищется по полю `name` в JSON; при совпадении: GET полного воркфлоу, merge с репо (`name`, `nodes`, `connections`, `settings`, при наличии `meta`), затем PUT. Иначе — POST. Тело в `uri` не передавать как `| to_json` при `body_format: json` (риск 400).
