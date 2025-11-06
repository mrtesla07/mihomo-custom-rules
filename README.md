# Генератор правил для Mihomo

Проект помогает собрать собственный список доменов и преобразовать его в формат YAML и бинарный `.mrs` для использования в Mihomo (Clash Meta).

## Структура

- `domains/` — исходные списки доменов (`.txt`, один домен в строке).
- `scripts/` — утилиты для сборки.
- `output/` — сюда складываются готовые файлы (`.yaml`, `.mrs`).

## Быстрый старт

1. Отредактируйте файл `domains/common.txt` или создайте свои списки в каталоге `domains/`.
2. Запустите скрипт сборки (см. ниже). Он подготовит YAML и при наличии бинарника `mihomo` соберёт `.mrs`.
3. Используйте `output/my-domains.yaml` или `output/my-domains.mrs` в своём конфиге Mihomo.

## Скрипты сборки

### Windows / PowerShell

```powershell
pwsh -File ./scripts/build.ps1 -ListPath ./domains/common.txt -OutputName my-domains
```

### Linux / macOS

```bash
bash ./scripts/build.sh --list ./domains/common.txt --output my-domains
```

Оба скрипта:
- читают домены, фильтруют пустые строки и комментарии (`#`),
- формируют YAML с префиксом `+.`,
- пытаются вызвать `mihomo convert-ruleset` для генерации `.mrs` (если `mihomo` есть в `PATH` или путь передан явно).

## Зависимости

- Установленный `mihomo` (версия не ниже 1.18). Если бинарник лежит не в `PATH`, передайте путь опцией `-MihomoPath` (PowerShell) или `--mihomo` (bash).
- PowerShell 7+ или совместимый (для Windows можно использовать `pwsh`, но скрипт должен работать и в Windows PowerShell 5.1).

## Формат входных файлов

- Одна строка — один домен (например, `example.com`).
- Пустые строки и строки, начинающиеся с `#`, игнорируются.
- Чтобы добавить конкретный поддомен, укажите его напрямую (`sub.example.com`). Для wildcard используйте только корневой домен — скрипт сам добавит `+.example.com`.

## Выходные файлы

- `output/<имя>.yaml` — YAML со структурой:
  ```yaml
  payload:
    - '+.example.com'
    - '+.example.org'
  ```
- `output/<имя>.mrs` — бинарный ruleset, если удалось запустить `mihomo convert-ruleset`.

## Проверка результата

Если требуется убедиться, что `.mrs` корректный, выполните:

```bash
mihomo convert-ruleset domain mrs ./output/my-domains.mrs /dev/null
```

Команда завершится без ошибок, если файл валиден.

## Что дальше

- Добавьте новые списки в `domains/` и укажите их скрипту.
- Настройте GitHub Actions по образцу [legiz-ru/mihomo-rule-sets](https://github.com/legiz-ru/mihomo-rule-sets), чтобы автоматизировать сборку.
- Интегрируйте готовые файлы в ваш конфиг Clash Meta/Mihomo, используя `rule-providers`.

## GitHub Actions

В репозитории есть workflow `.github/workflows/build.yml`, который:
- запускается на push, pull request и вручную (`workflow_dispatch`);
- устанавливает `mihomo` и прогоняет скрипт `scripts/build.sh` для каждого `.txt` в `domains/`;
- складывает результирующие `.yaml` и `.mrs` в каталог `output/` и публикует их артефактами (`mihomo-rulesets`).
- при запуске не из pull request создаёт GitHub Release с актуальными файлами (последний доступен по ссылке вида `https://github.com/<owner>/<repo>/releases/latest/download/<имя_файла>`).
- синхронизирует содержимое `output/` в ветку `raw`, откуда файлы доступны по прямым ссылкам `https://raw.githubusercontent.com/<owner>/<repo>/raw/<имя_файла>`.

Получить артефакты можно на вкладке **Actions** в выбранном прогоне.

> ⚠️ Для публикации релизов нужно, чтобы в настройках репозитория Actions → General → Workflow permissions была включена опция «Read and write permissions» (или явно задано `permissions: contents: write` в workflow — уже сделано в `build.yml`).
