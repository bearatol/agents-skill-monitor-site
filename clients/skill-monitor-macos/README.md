# Local Skill Monitor for macOS

## Русский

Приложение читает выбранные папки на Mac. По умолчанию выбрана `~/.agents`.
Область поиска охватывает саму выбранную папку, а не только вложенную `skills/`.
Другие папки можно добавить или исключить вручную. Ссылки за пределы выбранных
папок не читаются. Выбор папок, язык и история хранятся только до закрытия приложения.
Автообновление выполняется раз в 30 секунд; его можно выключить. Журнал сохраняет
последние 500 событий до подтверждения. Смена папок начинает историю заново.
Если чтение неполное, сравнение приостанавливается. Последняя полная точка
отсчёта сохраняется до восстановления чтения.

Индекс включает навыки из `SKILL.md`, агентов из Markdown в `agents/` и
метаданные MCP из `.mcp.json`, `mcp.json`, `mcp-config.json` и
`claude_desktop_config.json` с полями `mcpServers` или `mcp_servers`.
Для RAG читаются объявления `sources[]` в `rag.sources.json` и `rag.json`.
Файлы `index.faiss` и `chroma.sqlite3` служат только признаками наличия индекса:
их содержимое не читается. TOML и другие форматы RAG и векторных хранилищ
пока не поддерживаются.

Граф показывает только явные ссылки и отмечает, какие из них найдены в индексе,
а какие не удалось сопоставить. Это не подтверждает работающие соединения.
Изменения отдельных записей MCP и RAG отслеживаются независимо от соседних
записей в том же файле. При одинаковых id источников RAG сопоставление их
изменений может оставаться неоднозначным.
Пассивные проверки текста и метаданных конфигурации показывают замечания с
подтверждениями. Они не анализируют весь код и содержимое файлов и не дают
заключения об отсутствии вредоносного ПО.

Фильтр "С замечаниями проверок" включает и информационные
замечания. Они не обязательно указывают на проблему. Справка "Где искать" объясняет выбор папок, напоминает о папке по умолчанию `~/.agents`
и показывает текущие выбранные пути. При ошибке формата конфигурации можно
скопировать путь, проверить и исправить JSON вручную, затем обновить список.

Кнопка "Обмен с вашим ИИ" копирует общий запрос на выбранном языке для вашего ИИ.
Его ответ можно вставить как JSON: `{"folders":[{"path":"...","reason":"..."}]}`.
Предложенные папки не проверены и не выбраны. Они попадают в область поиска
только после явного включения. Вся домашняя папка автоматически не сканируется.

Клиент не обращается к сети, не запускает и не устанавливает пакеты, не изменяет
файлы и не исправляет замечания автоматически. Прямое подключение модели и запуск
антивирусного движка отложены до независимого ревью в изолированной среде.
Клиент не меняет учёт пакетов APM. Установка и обновление через APM
в этом клиенте пока не подключены.

## English

The app reads selected folders on the Mac, starting with `~/.agents`.
The search scope covers the selected folder itself, rather than switching to
its `skills/` child. Add or exclude other folders manually. Links outside the
selected folders are not read. Folder choices, language and history last only
until the app closes.
Optional auto-refresh reads folders every 30 seconds. The journal retains the
latest 500 events until marked reviewed. Changing folders starts a new history.
Incomplete reads pause comparison and preserve the last complete baseline
until reading recovers.

The index includes skills from `SKILL.md`, agents from Markdown under `agents/`,
and MCP metadata from `.mcp.json`, `mcp.json`, `mcp-config.json` and
`claude_desktop_config.json` with `mcpServers` or `mcp_servers` fields.
For RAG, it reads `sources[]` declarations in `rag.sources.json` and `rag.json`.
Files named `index.faiss` and `chroma.sqlite3` are index hints only; their contents
are not read. TOML and other RAG and vector-store formats are not supported yet.

The graph shows explicit references and marks whether they resolve to indexed
records. It does not prove runtime connections.
Each MCP or RAG entry is tracked independently of sibling entries in the same
file. Changes to RAG sources with conflicting IDs can remain ambiguous.
Passive checks of text and configuration metadata show notices with evidence.
They do not scan all code
or file contents and do not establish that materials are free of malware.

The "With check findings" filter includes informational
advisories, which do not necessarily indicate a problem. "Where to look" explains folder selection, identifies the default `~/.agents` folder
and shows the currently selected paths. For an invalid configuration, copy its
path, check and correct the JSON manually, then refresh the list.

"Exchange with your AI" copies a generic query in the selected language for your own AI.
Paste its response as JSON: `{"folders":[{"path":"...","reason":"..."}]}`.
Suggested folders are unverified and unchecked. They enter the search scope
only after explicit inclusion. The app does not automatically scan the home folder.

The client makes no network requests, runs or installs no packages, changes no
files and applies no automatic fixes. A live model connection and antivirus
engine execution are deferred pending an independent review in an isolated
environment. The client leaves APM ownership records unchanged. APM installation
and update controls are not integrated.

## 简体中文

应用读取 Mac 上选定的文件夹, 默认选择 `~/.agents`。
搜索范围涵盖所选文件夹本身, 不会自动改为其 `skills/` 子目录。
其他文件夹可以手动添加或排除。不会读取指向所选目录之外的链接。
文件夹选择、语言和历史记录仅保留到应用关闭。
可选的自动刷新每 30 秒读取一次文件夹。日志保留最近 500 条事件，直到标记为已查看。
更改文件夹会重新开始记录历史。
读取不完整时会暂停比较，并保留上次完整读取的基准，直到读取恢复。

索引包含 `SKILL.md` 中的技能、`agents/` 下 Markdown 文件中的智能体,
以及 `.mcp.json`、`mcp.json`、`mcp-config.json` 和
`claude_desktop_config.json` 中 `mcpServers` 或 `mcp_servers` 字段的 MCP 元数据。
RAG 元数据来自 `rag.sources.json` 和 `rag.json` 中的 `sources[]` 声明。
`index.faiss` 和 `chroma.sqlite3` 仅作为存在索引的线索, 不读取其内容。
暂不支持 TOML 和其他 RAG 或向量存储格式。

关系图只显示明确声明的引用, 并标明能否匹配到已索引的记录。
这不能证明运行时连接有效。同一文件中的 MCP 或 RAG 条目分别跟踪，其他条目的修改
不会把当前条目标记为已更改。若 RAG 来源的标识符重复，修改后可能无法唯一匹配。
对文本和配置元数据的被动检查会显示提示及其依据。
这些检查不扫描全部代码或文件内容, 也不能证明资源不含恶意软件。

"有检查提示"筛选也包含信息性提示，不一定代表存在问题。
"在哪里查找"说明如何选择文件夹，注明默认文件夹 `~/.agents`，
并显示当前所选路径。如配置格式无效，可复制路径，手动检查和修正 JSON，
然后刷新列表。

"与您使用的 AI 手动交换"会复制当前语言的通用查询, 供你发送给自己的 AI。
将回复以 JSON 格式粘贴回来: `{"folders":[{"path":"...","reason":"..."}]}`。
建议的文件夹未经验证, 默认不勾选。只有明确选择纳入后才会进入搜索范围。
应用不会自动扫描整个主目录。

客户端不访问网络, 不运行或安装软件包, 不修改文件, 也不自动修复问题。
直接连接模型和运行杀毒引擎的功能暂缓, 等待在隔离环境中进行独立审核。
客户端不修改 APM 的软件包所有权记录，尚未接入 APM 的安装和更新功能。

## Download and compatibility

[Download for Mac](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.2.3-preview/AgentsSkillMonitor-macOS-universal2.zip)
contains both Apple Silicon (arm64) and Intel (x86_64) code. The deployment
target is macOS 13 or later. Native Windows and Linux clients and binaries are
not available.

This preview has an ad-hoc signature and is not notarized by Apple. macOS may
block the first launch. Launch on a clean Mac has not been tested.

The test suite passed 503 assertions and 11 real-filesystem scenarios on each
architecture, with no skips: arm64 natively and x86_64 through Rosetta on Apple
Silicon. These runs do not verify operation on physical Intel Macs or macOS 13.
VoiceOver and the minimum 1040×650 window have not been verified.

## Build

Use the installed Apple Swift toolchain and Python 3 on macOS. No packages are
downloaded. Run from the repository root to build one app for both types of Mac:

```sh
python3 -B clients/skill-monitor-macos/build.py --arch universal2
```

For an Intel-only build:

```sh
python3 -B clients/skill-monitor-macos/build.py --arch x86_64
```

Use `--arch arm64` for Apple Silicon only. Omitting `--arch` uses the build
machine's architecture.

Run the metadata, folder-proposal, model and filesystem checks separately for
each architecture:

```sh
python3 -B clients/skill-monitor-macos/test.py --arch arm64
python3 -B clients/skill-monitor-macos/test.py --arch x86_64
```

Running x86_64 tests on Apple Silicon requires Rosetta to be installed. The test
command does not install it. An Intel Mac cannot run the arm64 tests.

With an explicit `--arch`, the application and ZIP are written under
`build/skill-monitor-macos/<arch>/`. Without it they go directly under
`build/skill-monitor-macos/`. Each build targets macOS 13 or later. Local builds
have ad-hoc signatures and are not notarized for distribution.
