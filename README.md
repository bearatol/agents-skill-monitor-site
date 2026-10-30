# Skill Monitor

[Русский](#русский) · [English](#english) · [简体中文](#简体中文)

## Русский

Skill Monitor показывает навыки, агентов, MCP-серверы и источники RAG в выбранных
папках на Mac. По умолчанию выбрана `~/.agents`. Это предварительная версия 0.2.3.

[Скачать ZIP для Mac с Apple Silicon](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.2.3-preview/AgentsSkillMonitor-macOS-arm64.zip).
Нужны macOS 13 или новее и Apple Silicon (arm64). Сборки для Intel Mac нет.
Сборка подписана ad-hoc и не заверена Apple. Первый запуск может быть заблокирован;
запуск на чистом Mac не проверен.

Клиент читает поддерживаемые метаданные `SKILL.md`, агентов, MCP и RAG, а не все
форматы. Ссылки показывают объявления, а не работающие соединения. Пассивные
замечания помогают выбрать, что проверить вручную; это не антивирус и не аудит
исходного кода. Обмен с вашим ИИ работает через копирование запроса и вставку
ответа, без подключения модели.

Обновление раз в 30 секунд можно включить на время работы приложения. Выбор
папок, язык и журнал хранятся в памяти до закрытия. Клиент не обращается к сети,
не собирает телеметрию, не изменяет файлы и не запускает пакеты. Учёт APM
не меняется; установка и обновление через APM не подключены.

Пройдены 503 проверки и 11 сценариев с реальной файловой системой, без пропусков.
Общий интерфейс прошёл 21 проверку и независимое ревью исходников и синтетической
DOM-среды. Это не проверка в реальном браузере или на трёх ОС. VoiceOver,
минимальное окно 1040×650 и работа с реальными пользователями не проверены.
Независимое изолированное ревью безопасности не завершено.

Для Windows и Linux подготовлен только общий интерфейс. Нативного подключения,
общего ядра, сохранения настроек и сборок нет. Подробности:
[Mac-клиент](clients/skill-monitor-macos/README.md),
[общий интерфейс](clients/skill-monitor-desktop/README.md),
[версия 0.2.3-preview](https://github.com/bearatol/agents-skill-monitor-site/releases/tag/v0.2.3-preview),
[сайт](https://bearatol.github.io/agents-skill-monitor-site/).

## English

Skill Monitor lists skills, agents, MCP servers and RAG sources in selected
folders on your Mac. `~/.agents` is selected by default. This is preview 0.2.3.

[Download the ZIP for Apple Silicon Mac](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.2.3-preview/AgentsSkillMonitor-macOS-arm64.zip).
Requires macOS 13 or later and Apple Silicon (arm64). No Intel Mac build.
The build has an ad-hoc signature and is not notarized by Apple. macOS may block
the first launch; launch on a clean Mac has not been tested.

The client reads supported metadata for `SKILL.md`, agents, MCP and RAG, not every
format. Links show declarations, not working connections. Passive findings help
you decide what to review manually; they are not antivirus protection or a
source-code audit. Exchange with your AI uses a copied request and pasted
response, with no model connection.

You can enable refresh every 30 seconds while the app is open. Folder choices,
language and the journal stay in memory until you quit. The client makes no
network requests, collects no telemetry, changes no files and runs no packages.
APM ownership is unchanged; APM installation and updates are not connected.

The client passed 503 assertions and 11 real-filesystem scenarios, with no skips.
The shared interface passed 21 checks and an independent review of source and a
synthetic DOM. This is not verification in a real browser or across three operating
systems. VoiceOver, the minimum 1040×650 window and real-user usability have not
been verified. Independent isolated security review is not complete.

Only the shared interface is prepared for Windows and Linux. There is no native
connection, shared core, saved settings or binary for them. See the
[Mac client](clients/skill-monitor-macos/README.md),
[shared interface](clients/skill-monitor-desktop/README.md),
[0.2.3-preview release](https://github.com/bearatol/agents-skill-monitor-site/releases/tag/v0.2.3-preview)
and [website](https://bearatol.github.io/agents-skill-monitor-site/).

## 简体中文

Skill Monitor 在 Mac 上列出所选文件夹中的技能、智能体、MCP 服务器和 RAG 数据源。
默认选择 `~/.agents`。当前为 0.2.3 预览版。

[下载 Apple Silicon Mac 版 ZIP](https://github.com/bearatol/agents-skill-monitor-site/releases/download/v0.2.3-preview/AgentsSkillMonitor-macOS-arm64.zip)。
需要 macOS 13 或更高版本和 Apple Silicon（arm64）。暂无 Intel Mac 构建。
构建使用 ad-hoc 签名，未经 Apple 公证。macOS 可能阻止首次启动；
尚未在干净的 Mac 环境中测试启动。

客户端读取 `SKILL.md`、智能体、MCP 和 RAG 的受支持元数据，并非所有格式。
关联表示声明，不代表连接实际有效。被动检查提示帮助您决定手动核查哪些内容，
并非杀毒保护或源代码审计。与您使用的 AI 交换信息需要复制请求并粘贴回复，
应用未连接模型。

可选择在应用打开时每 30 秒刷新。文件夹选择、语言和日志保存在内存中，退出即清除。
客户端不发送网络请求、不收集遥测数据、不修改文件，也不运行软件包。
不改变 APM 所有权记录，尚未接入 APM 的安装和更新功能。

客户端通过 503 项断言检查和 11 个真实文件系统场景，无跳过项。
共享界面通过 21 项检查，并接受了覆盖源代码和模拟 DOM 环境的独立审查。
这并不代表已在真实浏览器或三个操作系统上验证。尚未验证 VoiceOver、
1040×650 最小窗口和真实用户的可用性。独立隔离安全审查尚未完成。

Windows 和 Linux 目前仅准备了共享界面，尚无原生连接、共享核心、设置保存功能或安装包。
详见 [Mac 客户端](clients/skill-monitor-macos/README.md)、
[共享界面](clients/skill-monitor-desktop/README.md)、
[0.2.3-preview 版本](https://github.com/bearatol/agents-skill-monitor-site/releases/tag/v0.2.3-preview)
和[网站](https://bearatol.github.io/agents-skill-monitor-site/)。

## Build and checks / Сборка и проверки / 构建与检查

The native Mac build requires Xcode Command Line Tools and Python 3. Run from
the repository root. It targets the build machine's architecture; the
preview ZIP is arm64 only.

Нативная сборка для Mac требует Xcode Command Line Tools и Python 3. Команды
выполняются из корня репозитория. Архитектура соответствует машине сборки;
ZIP этой предварительной версии предназначен только для arm64.

原生 Mac 构建需要 Xcode Command Line Tools 和 Python 3。请在仓库根目录运行。
构建目标为构建机器的架构；本预览版 ZIP 仅适用于 arm64。

```sh
python3 -B clients/skill-monitor-macos/build.py
python3 -B clients/skill-monitor-macos/test.py
node clients/skill-monitor-desktop/tests/test.js
```

The last command requires Node.js and checks the presentation, not native OS behavior.
Последняя команда требует Node.js и проверяет представление, а не нативную работу на ОС.
最后一条命令需要 Node.js，检查界面呈现，不验证原生系统行为。

[License / Лицензия / 许可证](LICENSE)
