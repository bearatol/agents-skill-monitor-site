# Skill Monitor 0.3.0-preview

[Русский](#русский) · [English](#english) · [简体中文](#简体中文)

## Русский

Skill Monitor показывает навыки, агентов, MCP и объявления источников RAG
в выбранных папках Mac. По умолчанию выбрана `~/.agents`.

[Скачать ZIP для Mac](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip). Нужна macOS 13 или новее.
Один universal2-архив содержит arm64 и x86_64. Предварительная сборка подписана
ad-hoc, без нотариализации Apple. macOS может заблокировать первый запуск.
Запуск на чистом Mac ещё не проверен.

В 0.3.0 появились заметные кнопки с рамками, общий переход к замечаниям и число
замечаний с текстом уровня важности. Можно проверить один файл описания:
отчёт показывает возможные признаки, файл и строки при наличии, SHA-256 и границы проверки.
Вспомогательный код и содержимое RAG не исследуются. Заявленные связи
не подтверждают работающие соединения; отсутствие замечаний не доказывает безопасность.

Локальный ИИ подключается по желанию через loopback-сервер, совместимый с OpenAI:
MLX (9944), Ollama (11434), LM Studio (1234) или вручную заданный порт.
Сначала явно проверьте подключение, выберите модель и прочитайте точный
предпросмотр. Каждая отправка требует нового нажатия. Скрытие может пропустить
секреты; сервер может сохранять или пересылать запросы. Loopback не гарантирует
работу без интернета. Ответ модели показан обычным текстом и не проверен;
неполные ответы отклоняются. Серверы не запускаются автоматически, API-ключи не поддерживаются.

Обмен предложениями папок через копирование и вставку остаётся отдельным процессом.
Предложения не проверены и не выбраны до вашего решения. Автообновление раз
в 30 секунд можно включить. Журнал хранит до 500 событий. Папки, язык, настройки,
журнал и ответы проверки остаются в памяти до выхода. Смена папок сбрасывает журнал.
Клиент не применяет исправления, не запускает компоненты, не устанавливает
плагины или пакеты, не изменяет исходники и не собирает телеметрию.
Установка и обновление через APM не подключены.

Для каждой архитектуры пройдены 739 проверок, тест упаковки и 11 сценариев
с реальной файловой системой без пропусков: arm64 напрямую и x86_64 через
Rosetta на Apple Silicon. Готовое приложение выполнило GET и POST с тестовым
loopback-сервером; настоящий вывод нейромодели не проверялся. Не проверены
физический Intel Mac, macOS 13, всё минимальное окно, работа только
с клавиатурой, VoiceOver и удобство для реальных пользователей.
Для Windows и Linux сборок нет; неподключённый общий интерфейс сохраняет 21 проверку.

## English

Skill Monitor lists skills, agents, MCP entries and RAG source declarations in
selected Mac folders. `~/.agents` is selected by default.

[Download the ZIP for Mac](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip). Requires macOS 13 or later.
One universal2 archive includes arm64 and x86_64. This preview has an ad-hoc
signature and is not notarized by Apple. macOS may block the first launch.
Launch on a clean Mac has not been tested.

Version 0.3.0 adds visible bordered buttons, global findings navigation and
finding counts with severity text. Review one descriptor for suspected signals,
file evidence and line numbers where available, SHA-256 and coverage limits. Helper code and RAG contents
are outside the review. Declared links do not establish working connections;
no findings does not establish safety.

Optionally connect to an OpenAI-compatible model through a loopback server:
MLX (9944), Ollama (11434), LM Studio (1234), or a manually entered port.
Explicitly check the connection, choose a model and inspect the exact preview.
Each send needs a new click. Redaction may miss secrets; the server may store
or forward prompts. Loopback does not guarantee offline execution. Model output
is unverified plain text; incomplete responses are rejected. The app does not
start servers automatically or support API keys.

Copy-and-paste folder suggestions remain a separate manual workflow.
Suggestions are unverified and unchecked until you choose them. Optional refresh
runs every 30 seconds. The journal holds up to 500 events. Folders, language,
settings, journal and audit responses stay in memory until quit. Changing folders
resets the journal. The client does not apply fixes, run components, install
plugins or packages, modify source files or collect telemetry. APM installation
and update controls are not connected.

Each architecture passed 739 assertions, a packaging test and 11 real-filesystem
scenarios with no skips: arm64 natively and x86_64 through Rosetta on Apple
Silicon. The bundled app completed GET and POST against a synthetic loopback
fixture; real model inference was not tested. Physical Intel hardware, macOS 13,
the full minimum window, keyboard-only use, VoiceOver and human usability remain
unverified. There are no Windows or Linux binaries; the unconnected shared
interface retains 21 checks.

## 简体中文

Skill Monitor 列出 Mac 所选文件夹中的技能、智能体、MCP 条目和 RAG 数据源声明。
默认选择 `~/.agents`。

[下载 Mac 版 ZIP](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.3.0-preview/AgentsSkillMonitor-macOS-universal2.zip)。需要 macOS 13 或更高版本。
一个 universal2 压缩包包含 arm64 和 x86_64。预览构建使用 ad-hoc 签名，
未经 Apple 公证。macOS 可能阻止首次启动。尚未在干净的 Mac 环境中测试启动。

0.3.0 增加了清晰的带边框按钮、全局检查提示入口，以及带级别文字的提示计数。
可检查一个描述文件，查看疑似特征、文件及可用的行号证据、SHA-256 及检查范围限制。
不检查辅助代码或 RAG 内容。声明的关联不能证明运行时连接有效；没有提示不能证明安全。

可选择通过兼容 OpenAI 的回环服务器连接模型：MLX（9944）、Ollama（11434）、
LM Studio（1234），或手动输入端口。先明确检查连接、选择模型并检查完整预览。
每次发送都需要重新点击。自动隐藏可能遗漏敏感信息；服务器可能保存或转发提示词。
回环连接不保证离线运行。模型回复以未经验证的纯文本显示，不完整的回复会被拒绝。
应用不会自动启动服务器，不支持 API 密钥。

通过复制粘贴交换文件夹建议仍是独立的手动流程。建议未经验证，默认不勾选，需由您选择。
可开启每 30 秒刷新，日志最多保留 500 条事件。文件夹、语言、设置、日志和检查回复
仅保存在内存中，退出即清除。更改文件夹会重置日志。客户端不应用修复、不运行组件、
不安装插件或软件包、不修改源文件，也不收集遥测数据。尚未接入 APM 安装和更新功能。

每种架构均通过 739 项断言检查、一项打包测试及 11 个真实文件系统场景，无跳过项：
在 Apple Silicon 上原生运行 arm64，并通过 Rosetta 运行 x86_64。打包后的应用已对
模拟回环服务器完成 GET 和 POST，未测试真实模型推理。尚未验证实体 Intel Mac、
macOS 13、完整最小窗口、纯键盘操作、VoiceOver 和真人可用性。
没有 Windows 或 Linux 安装包；未接入原生功能的共享界面保留 21 项检查。

## Details / Подробнее / 详情

[Mac client / Mac-клиент / Mac 客户端](clients/skill-monitor-macos/README.md) ·
[Shared interface / Общий интерфейс / 共享界面](clients/skill-monitor-desktop/README.md) ·
[0.3.0-preview release](https://github.com/bearatol/agents-skill-monitor-site/releases/tag/v0.3.0-preview) ·
[Website / Сайт / 网站](https://bearatol.github.io/agents-skill-monitor-site/)

The descriptor review is an original workflow aligned with `ceo-ai:security` 0.9.
SkillSpector, Docker and an antivirus engine are not bundled or required.
Проверка описания основана на оригинальном процессе, согласованном с подходом
`ceo-ai:security` 0.9. SkillSpector, Docker и антивирусный движок не включены и не требуются.
描述文件检查是与 `ceo-ai:security` 0.9 方法一致的原创流程，
不包含或依赖 SkillSpector、Docker 或杀毒引擎。

## Build and checks / Сборка и проверки / 构建与检查

The native Mac build requires Xcode Command Line Tools and Python 3. Run from
the repository root. The universal2 ZIP contains arm64 and x86_64 code.
Use `--arch x86_64` for Intel only or `--arch arm64` for Apple Silicon only.

Нативная сборка для Mac требует Xcode Command Line Tools и Python 3. Команды
выполняются из корня репозитория. ZIP universal2 содержит arm64 и x86_64.
Для отдельной архитектуры используйте `--arch x86_64` или `--arch arm64`.

原生 Mac 构建需要 Xcode Command Line Tools 和 Python 3。请在仓库根目录运行。
universal2 ZIP 包含 arm64 和 x86_64。单独构建时使用 `--arch x86_64` 或 `--arch arm64`。

```sh
python3 -B clients/skill-monitor-macos/build.py --arch universal2
python3 -B clients/skill-monitor-macos/test.py --arch arm64
python3 -B clients/skill-monitor-macos/test.py --arch x86_64
node clients/skill-monitor-desktop/tests/test.js
```

The x86_64 tests require Rosetta on Apple Silicon. An Intel Mac cannot run arm64 tests.
На Apple Silicon для тестов x86_64 нужна Rosetta. Mac с Intel не запускает тесты arm64.
在 Apple Silicon 上运行 x86_64 测试需要 Rosetta。Intel Mac 无法运行 arm64 测试。

The last command requires Node.js and checks the presentation, not native OS behavior.
Последняя команда требует Node.js и проверяет представление, а не нативную работу на ОС.
最后一条命令需要 Node.js，检查界面呈现，不验证原生系统行为。

[License / Лицензия / 许可证](LICENSE)
