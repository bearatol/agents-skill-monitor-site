# Skill Monitor for macOS 0.3.0-preview

## Русский

Предварительная версия 0.3.0 доступна для macOS 13+ на Apple Silicon и Intel.
[Скачать universal2 ZIP](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip). Сборка подписана ad-hoc, без нотариализации Apple.

Приложение показывает навыки, агентов, MCP и объявления источников RAG
в выбранных папках Mac. По умолчанию выбрана `~/.agents`. Область чтения
охватывает саму выбранную папку и её содержимое, а не только вложенную `skills/`.
Другие папки можно добавить или исключить вручную. Ссылки за пределы выбранных
папок не читаются. Выбор папок, язык, история, настройки подключения, отчёты
и ответы модели хранятся только до закрытия приложения.

Индекс включает `SKILL.md`, Markdown агентов в `agents/`, MCP из `.mcp.json`,
`mcp.json`, `mcp-config.json` и `claude_desktop_config.json` с полями
`mcpServers` или `mcp_servers`. Для RAG читаются объявления `sources[]`
в `rag.sources.json` и `rag.json`. Имена `index.faiss` и `chroma.sqlite3`
служат только признаками индекса; их содержимое не читается. TOML и другие
форматы RAG и векторных хранилищ пока не поддерживаются.

Кнопка «Посмотреть замечания проверок» открывает компоненты с замечаниями
и сбрасывает поисковые фильтры. В списке видны число замечаний, значок и текст
уровня важности. Информационные замечания не обязательно указывают на проблему.
Замечания при чтении показаны отдельно. Связи отражают явные объявления
и совпадения в индексе, но не подтверждают работающие соединения.

Автообновление читает папки каждые 30 секунд; его можно выключить.
Журнал хранит последние 500 событий до подтверждения. Смена папок начинает
историю заново. При неполном чтении сравнение приостанавливается и сохраняет
последнюю полную точку отсчёта. Записи MCP и RAG отслеживаются отдельно;
при повторяющихся идентификаторах RAG сопоставление изменений может быть
неоднозначным. Для исправления неверного JSON можно скопировать путь,
изменить файл вручную и обновить список.

### Проверка исходника и локальная модель

1. Выберите компонент и нажмите «Проверить безопасность». Статический отчёт
   и предпросмотр работают без модели. Проверяется один выбранный файл описания
   в пределах выбранных папок. Для навыка или агента готовится ограниченный
   фрагмент с номерами строк и скрытием распознанных секретов. Для MCP и RAG
   готовится только структурное резюме выбранной записи, без исходной конфигурации
   и соседних записей. Отчёт показывает возможные признаки, относительный путь,
   строки при наличии, SHA-256 и границы проверки.
2. Для анализа моделью откройте «Локальный ИИ». Есть примеры адресов MLX
   `http://127.0.0.1:9944/v1`, Ollama `http://127.0.0.1:11434/v1`
   и LM Studio `http://127.0.0.1:1234/v1`, а также ручной ввод адреса.
   «Проверить подключение» явно получает список моделей через GET. Затем выберите
   модель. Приложение не запускает сервер и не проверяет подключение автоматически.
   API-ключи не поддерживаются.
3. Проверьте точный текст предпросмотра: автоматическое скрытие может пропустить
   секреты. Только нажатие «Отправить этот текст выбранной модели» запускает POST
   с показанным сообщением и отдельной постоянной инструкцией для проверки без
   внесения изменений на выбранном языке. Перед отправкой исходник перечитывается
   для проверки неизменности. Смена компонента, папок или языка сбрасывает
   предпросмотр. Проверка подключения, смена адреса или модели сохраняют статический
   отчёт и предпросмотр, отменяют текущий запрос и очищают прежний ответ модели.
   Для отправки на показанный сервер выбранной модели всегда нужно новое нажатие.
   Обычное автообновление сохраняет неизменившиеся результаты.
4. Ответ модели показан обычным текстом как непроверенные рекомендации. Его можно
   выделить и скопировать. Приложение не выполняет команды из ответа. Отмена
   запроса или закрытие окна останавливают текущий запрос.

Разрешён только сервер на этом компьютере через loopback. Такой адрес
не гарантирует локальное выполнение модели: сам сервер может пересылать
или сохранять запросы. Проверка неполная: вспомогательные файлы, связанный
исполняемый код и содержимое RAG не исследуются. Антивирусный движок и поиск
по базам известных уязвимостей не используются. Найденный шаблон может быть
примером, а отсутствие замечаний не подтверждает безопасность.

Это оригинальный процесс, согласованный с подходом `ceo-ai:security` 0.9:
ограниченная область, недоверенные входные данные, основания для замечаний
и явное указание непроверенного. SkillSpector и Docker в приложение не включены
и для этого процесса не нужны. Клиент не устанавливает плагины или пакеты,
не запускает компоненты, не изменяет исходники и не применяет исправления
автоматически. Учёт пакетов APM не меняется; установка и обновление через APM
не подключены.

«Обмен списком папок» остаётся отдельным ручным процессом. Скопируйте запрос
своему ИИ и вставьте ответ вида
`{"folders":[{"path":"...","reason":"..."}]}`. Предложенные папки не проверены
и не выбраны. Они добавляются только после явного выбора. Вся домашняя папка
автоматически не сканируется.

## English

Preview 0.3.0 is available for macOS 13+ on Apple Silicon and Intel.
[Download the universal2 ZIP](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip). The build has an ad-hoc signature and is not notarized by Apple.

The app lists skills, agents, MCP entries and RAG source declarations in
selected Mac folders, starting with `~/.agents`. It reads the selected folder
and its contents, rather than restricting the scope to its `skills/` child.
Add or exclude other folders manually. Links outside selected folders are not
read. Folder choices, language, history, connection settings, reports and model
responses last only until the app closes.

The index includes `SKILL.md`, agent Markdown under `agents/`, and MCP entries
from `.mcp.json`, `mcp.json`, `mcp-config.json` and `claude_desktop_config.json`
with `mcpServers` or `mcp_servers` fields. RAG declarations come from `sources[]`
in `rag.sources.json` and `rag.json`. Names such as `index.faiss` and
`chroma.sqlite3` are index hints only; their contents are not read. TOML and
other RAG and vector-store formats are not supported yet.

"View check findings" opens components with findings and resets search filters.
List rows show a finding count, severity symbol and severity text. Informational
findings do not necessarily indicate a problem. Read notices are shown
separately. Links represent explicit declarations and matches in the index,
which do not prove runtime connections.

Optional auto-refresh reads folders every 30 seconds. The journal retains the
latest 500 events until marked reviewed. Changing folders starts a new history.
Incomplete reads pause comparison and preserve the last complete baseline.
MCP and RAG entries are tracked separately; conflicting RAG identifiers can
make change matching ambiguous. For invalid JSON, copy its path, correct the
file manually and refresh the list.

### Source review and a local model

1. Select a component and choose "Review security". The static report and preview
   work without a model connection. The review reads one selected descriptor
   within the selected folders. For a skill or agent, it prepares a bounded
   excerpt with line numbers and redaction of recognized secret patterns. For
   MCP and RAG, it prepares only a structural summary of the selected entry,
   excluding raw configuration and sibling entries. The report shows suspected
   signals, a relative file path, line evidence where available, SHA-256 and
   coverage limits.
2. For model analysis, open "Local AI". Presets cover MLX at
   `http://127.0.0.1:9944/v1`, Ollama at `http://127.0.0.1:11434/v1`
   and LM Studio at `http://127.0.0.1:1234/v1`; you can also enter an address.
   "Check connection" explicitly fetches the model list through GET. Then choose
   a model. The app does not launch the server or check the connection
   automatically. API keys are not supported.
3. Inspect the exact preview: automatic redaction may miss secrets. Only
   "Send this preview to selected model" starts a POST containing the shown user
   message and a separate fixed instruction for a read-only review in the selected
   language. The source is reread before sending to check that it is unchanged.
   Changing the component, folders or language clears the preview. Checking the
   connection or changing the address or model preserves the static report and
   preview, cancels active requests and clears old model responses. Sending to
   the displayed server and model always requires a new click. Routine
   auto-refresh preserves unchanged results.
4. Model output appears as plain text with unverified suggestions that you can
   select and copy. The app does not execute suggested commands. Cancel the
   request or close the review window to stop an active request.

Only a loopback server on this computer is allowed. A loopback address does not
establish local model execution: the server itself may forward or store prompts.
Coverage is partial: helper files, supporting executable code and RAG contents
are not inspected. No antivirus engine or vulnerability advisory lookup is used.
A flagged pattern may be an example; no findings does not establish safety.

This is an original review workflow aligned with `ceo-ai:security` 0.9:
bounded scope, untrusted inputs, evidence and explicit coverage gaps.
SkillSpector and Docker are not bundled or required for this workflow.
The client does not install plugins or packages, run components, modify source
files or apply fixes automatically. APM ownership records remain unchanged;
APM installation and update controls are not integrated.

"Manual folder exchange" remains a separate manual process. Copy the request
to your own AI and paste its response as
`{"folders":[{"path":"...","reason":"..."}]}`. Suggested folders are unverified
and unchecked. They enter the scope only after explicit selection. The app
does not automatically scan the whole home folder.

## 简体中文

0.3.0 预览版适用于 macOS 13+ 的 Apple Silicon 和 Intel Mac。
[下载 universal2 ZIP](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip)。构建使用 ad-hoc 签名，未经 Apple 公证。

应用列出 Mac 所选文件夹中的技能、智能体、MCP 条目和 RAG 数据源声明，
默认选择 `~/.agents`。读取范围涵盖所选文件夹及其内容，不会仅限于其
`skills/` 子目录。其他文件夹可以手动添加或排除。不会读取指向所选文件夹
之外的链接。文件夹选择、语言、历史记录、连接设置、报告和模型回复仅保留到
应用关闭。

索引包含 `SKILL.md`、`agents/` 下的智能体 Markdown，以及 `.mcp.json`、
`mcp.json`、`mcp-config.json` 和 `claude_desktop_config.json` 中
`mcpServers` 或 `mcp_servers` 字段的 MCP 条目。RAG 声明来自
`rag.sources.json` 和 `rag.json` 中的 `sources[]`。`index.faiss` 和
`chroma.sqlite3` 仅作为索引线索，不读取其内容。暂不支持 TOML 和其他
RAG 或向量存储格式。

“查看检查提示”会打开有提示的组件并重置搜索筛选。列表显示提示数量、
级别图标和级别文字。信息性提示不一定代表存在问题。读取提示单独显示。
关联只代表明确声明及其与索引的匹配，不能证明运行时连接有效。

可选的自动刷新每 30 秒读取一次文件夹。日志保留最近 500 条事件，直到标记
为已查看。更改文件夹会重新开始记录历史。读取不完整时暂停比较并保留上次
完整基准。MCP 和 RAG 条目分别跟踪；RAG 标识符冲突可能使更改无法唯一匹配。
如 JSON 无效，可复制路径、手动修正文件，然后刷新列表。

### 源文件检查与本地模型

1. 选择组件并点击“检查安全性”。静态报告和预览无需连接模型。检查仅在所选
   文件夹内读取一个所选描述文件。对于技能或智能体，生成带行号的有限片段，
   并隐藏可识别的敏感信息模式。对于 MCP 和 RAG，仅生成所选条目的结构摘要，
   不包含原始配置或其他条目。报告显示疑似特征、相对文件路径、可用的行号证据、
   SHA-256 和检查范围限制。
2. 如需模型分析，打开“本地 AI”。预设包括 MLX `http://127.0.0.1:9944/v1`、
   Ollama `http://127.0.0.1:11434/v1` 和 LM Studio `http://127.0.0.1:1234/v1`，
   也可手动输入地址。“检查连接”会明确通过 GET 获取模型列表，然后选择模型。
   应用不会自动启动服务器或检查连接。不支持 API 密钥。
3. 检查完整预览：自动隐藏可能遗漏敏感信息。只有点击“将此预览发送给所选模型”
   才会发起 POST，包含显示的用户消息和另行固定的指令，要求以所选语言进行只读
   检查。发送前会重新读取源文件，确认其未更改。更改组件、文件夹或语言会清除
   预览。检查连接或更改地址、模型会保留静态报告和预览、取消当前请求并清除旧
   模型回复。每次向显示的服务器和模型发送都需要重新点击。普通自动刷新会保留
   未变化的结果。
4. 模型回复以纯文本显示，建议未经验证。可以选择并复制文本。应用不会执行
   建议中的命令。取消请求或关闭检查窗口可以停止正在进行的请求。

仅允许连接此电脑上的回环服务器。回环地址不能证明模型在本地运行：服务器
本身可能转发或保存提示词。检查范围有限，不检查辅助文件、相关可执行代码
或 RAG 内容，不使用杀毒引擎，也不查询漏洞公告。标记的模式可能只是示例；
没有提示不能证明安全。

这是与 `ceo-ai:security` 0.9 方法一致的原创检查流程，明确限定范围、将输入
视为不可信数据，并说明证据和未检查部分。应用不包含 SkillSpector 或 Docker，
此流程也不需要它们。客户端不安装插件或软件包、不运行组件、不修改源文件，
也不自动应用修复。APM 所有权记录保持不变；尚未接入 APM 安装和更新功能。

“手动交换文件夹列表”仍是独立的手动流程。将请求复制给自己的 AI，再粘贴
如下格式的回复：`{"folders":[{"path":"...","reason":"..."}]}`。
建议的文件夹未经验证，默认不勾选。只有明确选择后才加入读取范围。
应用不会自动扫描整个主目录。

## Availability and compatibility / Доступность / 可用性

The universal2 preview targets macOS 13+ and contains arm64 and x86_64 code.
It is ad-hoc signed and not notarized by Apple. Each architecture passed 739
assertions, a packaging test and 11 real-filesystem scenarios without skips:
arm64 natively and x86_64 through Rosetta on Apple Silicon. The bundled app
completed GET and POST against a synthetic loopback fixture, not a real model.
Clean-Mac launch, physical Intel hardware, macOS 13, the full minimum window,
keyboard-only use, VoiceOver and human usability remain unverified. No native
Windows or Linux binaries are available.

Universal2-сборка рассчитана на macOS 13+ и содержит arm64 и x86_64.
Подпись ad-hoc, без нотариализации Apple. Для каждой архитектуры пройдены
739 проверок, тест упаковки и 11 сценариев с реальной файловой системой без
пропусков: arm64 напрямую и x86_64 через Rosetta на Apple Silicon. Готовое
приложение выполнило GET и POST с тестовым loopback-сервером, без настоящей модели.
Не проверены чистый Mac, физический Intel Mac, macOS 13, всё минимальное окно,
работа только с клавиатурой, VoiceOver и удобство для реальных пользователей.
Нативных сборок для Windows и Linux нет.

Universal2 预览版面向 macOS 13+，包含 arm64 和 x86_64，使用 ad-hoc 签名，
未经 Apple 公证。每种架构均通过 739 项断言检查、一项打包测试和 11 个真实文件
系统场景，无跳过项：在 Apple Silicon 上原生运行 arm64，并通过 Rosetta 运行
x86_64。打包后的应用已对模拟回环服务器完成 GET 和 POST，未使用真实模型。
尚未验证干净 Mac、实体 Intel Mac、macOS 13、完整最小窗口、纯键盘操作、
VoiceOver 和真人可用性。没有 Windows 或 Linux 原生安装包。

## Build / Сборка / 构建

Use the installed Apple Swift toolchain and Python 3 on macOS. No packages are
downloaded by the build script. Run from the repository root:

На macOS нужны установленный инструментарий Apple Swift и Python 3.
Скрипт сборки не скачивает пакеты. Выполняйте команды из корня репозитория.

在 macOS 上使用已安装的 Apple Swift 工具链和 Python 3。构建脚本不会下载
软件包。请从仓库根目录运行以下命令。

```sh
python3 -B clients/skill-monitor-macos/build.py --arch universal2
```

Use `--arch arm64` for Apple Silicon only, or `--arch x86_64` for Intel only.
With an explicit `--arch`, the app and ZIP are written to
`build/skill-monitor-macos/0.3.0/<arch>/`. Omitting `--arch` uses the host
architecture and writes directly to `build/skill-monitor-macos/0.3.0/`.

Для отдельной архитектуры укажите `--arch arm64` или `--arch x86_64`.
С явным `--arch` приложение и ZIP попадают в
`build/skill-monitor-macos/0.3.0/<arch>/`. Без этого параметра используется
архитектура компьютера, а результат сохраняется в `build/skill-monitor-macos/0.3.0/`.

仅构建一种架构时，使用 `--arch arm64` 或 `--arch x86_64`。明确指定 `--arch`
时，应用和 ZIP 位于 `build/skill-monitor-macos/0.3.0/<arch>/`。省略该参数时，
使用构建电脑的架构，并直接输出到 `build/skill-monitor-macos/0.3.0/`。

Run inventory, metadata, folder-proposal, controller, local-connector,
descriptor-audit and filesystem checks separately for each architecture:

Проверки списка компонентов, метаданных, предложений папок, контроллера,
локального подключения и проверки исходника запускаются отдельно для каждой
архитектуры. 清单、元数据、文件夹建议、控制器、本地连接及描述文件检查按架构分别运行：

```sh
python3 -B clients/skill-monitor-macos/test.py --arch arm64
python3 -B clients/skill-monitor-macos/test.py --arch x86_64
```

Intel tests on Apple Silicon require Rosetta to be installed. The test command
does not install it. An Intel Mac cannot run the arm64 tests.

Для тестов Intel на Apple Silicon нужна установленная Rosetta. Команда тестов
её не устанавливает. Intel Mac не может запускать тесты arm64.

在 Apple Silicon 上运行 Intel 测试需要已安装 Rosetta，测试命令不会安装它。
Intel Mac 无法运行 arm64 测试。
