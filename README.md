# Генератор ruleset'ов для Mihomo

Репозиторий хранит исходники правил в формате JSON и автоматически собирает из них YAML‑файлы и бинарные `.mrs`, пригодные для использования в Mihomo (Clash Meta). Сборка может выполняться локально через `python scripts/build.py` или автоматически в GitHub Actions.

## Структура проекта

- `sources/domain/` — JSON c поведением `domain`. Пример: `tiktok.json`.
- `sources/classical/` — JSON для классических правил (`behavior: classical`). Пример: `russian-services.json`.
- `scripts/build.py` — основной скрипт генерации.
- `output/domain/` и `output/classical/` — результаты (`.yaml`, `.mrs`, для доменных списков дополнительно `.list`, для classical ещё `.txt`).

## Формат JSON

Каждый файл выглядит так:

```jsonc
{
  "version": 1,
  "rules": [
    {
      "domain_suffix": ["example.com", "example.org"],
      "domain": ["api.example.net"],
      "domain_keyword": ["shop"]
    }
  ]
}
```

Допустимые ключи в `rules`:

- `domain_suffix`, `domain`, `domain_keyword`
- `domain_regex`, `domain_keyword_regex`
- `ip_cidr`, `ip_cidr6`
- `process_name`, `process_name_regex`
- `payload` — если нужно добавить готовую строку вида `DOMAIN-SUFFIX,example.com`

Для доменных списков (`sources/domain`) используются только `domain_suffix`/`domain`. Для классических правил допускаются все поля, которые поддерживает Mihomo. **Строки вида `DOMAIN-SUFFIX,.ru` запрещены** — движок Mihomo не умеет обрабатывать wildcard для целых TLD и аварийно завершает работу.

## Локальная сборка

1. Установите `mihomo` и добавьте бинарник в `PATH`.
2. (Опционально) установите виртуальное окружение Python ≥3.8.
3. Выполните:
   ```bash
   python scripts/build.py
   ```
4. Готовые файлы появятся в `output/domain/` и `output/classical/`.

### Примеры результирующих файлов

- `output/domain/tiktok.yaml` / `output/domain/tiktok.mrs` / `output/domain/tiktok.list`
- `output/classical/russian-services.yaml` / `output/classical/russian-services.txt` (+ `.mrs`, если конвертер Mihomo отработал успешно; при ошибке `.mrs` не создаётся, смотрите предупреждение в логе)

## GitHub Actions

Workflow `.github/workflows/build.yml`:

- запускается на push, pull request и вручную (`workflow_dispatch`);
- устанавливает `mihomo`, запускает `python scripts/build.py`;
- публикует артефакт `mihomo-rulesets` (все `.yaml/.mrs/.list`);
- создает GitHub Release с актуальными файлами;
- синхронизирует каталог `output/` в ветку `raw` для прямого доступа (`https://raw.githubusercontent.com/<owner>/<repo>/raw/...`).

> ⚠️ В настройках репозитория Actions → General → Workflow permissions должна быть включена опция «Read and write permissions» (workflow уже содержит `permissions: contents: write`).

> ℹ️ У Mihomo есть баг: конвертация больших classical-листов иногда падает с `SIGSEGV`. Скрипт отмечает такую ситуацию предупреждением и просто не создаёт `.mrs`. Это ожидаемое поведение до тех пор, пока upstream не исправит проблему.

## Добавление новых правил

1. Создайте JSON в `sources/domain/` или `sources/classical/` по примеру выше.
2. Сделайте commit/push или запустите `python scripts/build.py`.
3. После успешного прогона workflow файлы будут доступны:
   - как артефакт `mihomo-rulesets`;
   - в релизах (`Releases` → `Latest`);
   - по прямым ссылкам, например  
     `https://raw.githubusercontent.com/mrtesla07/mihomo-custom-rules/raw/domain/tiktok.yaml`  
     `https://raw.githubusercontent.com/mrtesla07/mihomo-custom-rules/raw/classical/russian-services.mrs`.

## Полезные ссылки

- [Документация Mihomo по ruleset](https://wiki.metacubex.one/Rules/rule_set/)
- [legiz-ru/sb-rule-sets](https://github.com/legiz-ru/sb-rule-sets) — пример автоматизации и агрегации списков в формате sing-box. Многие идеи позаимствованы оттуда.
