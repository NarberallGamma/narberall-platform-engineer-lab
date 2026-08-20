# Установка и настройка ntpd

Пример инвентаря без генерации из SSH-config: `inventories/hosts.ini.example` (скопировать в `inventories/hosts.ini`). Сгенерированные `inventories/project_*.yml` не коммитить.

## Для всех проектов сразу

Список узлов:

```bash
./update_inventory --project-filter ".*" && ansible-playbook setup_ntpd.yml --list-hosts
```

Установка:

```bash
./update_inventory --project-filter ".*" && ansible-playbook setup_ntpd.yml
```

## Для одного проекта

Для вымышленного проекта **aproject**.

Список узлов:

```bash
./update_inventory --project-filter "aproject" && ansible-playbook setup_ntpd.yml --limit localhost,project_aproject --list-hosts
```

Установка:

```bash
./update_inventory --project-filter "aproject" && ansible-playbook setup_ntpd.yml --limit localhost,project_aproject
```
