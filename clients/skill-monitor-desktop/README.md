# Skill Monitor desktop interface

## Русский

Подготовлен интерфейс для будущего клиента macOS, Windows и Linux. Это пока
страница для проверки представления, а не приложение Tauri или готовые сборки.
Нативное подключение не реализовано. При открытии `index.html` страница не
получает доступ к папкам компьютера, не сканирует и не изменяет файлы.
Без подключения количество компонентов неизвестно.

Если показаны демонстрационные данные, это вымышленные примеры для проверки
интерфейса. Они не получены из файлов на компьютере. Сохранение настроек между
запусками пока не реализовано. Подключения к ИИ и антивирусу нет.

В интерфейсе подготовлен фильтр компонентов с замечаниями, включая
информационные. Справка объясняет, где искать компоненты, и указывает
`~/.agents` как папку по умолчанию. Это пояснение, а не результат чтения
компьютера. Подсказка при неверной конфигурации предлагает проверить JSON
вручную по указанному пути.

Откройте `index.html` из этой папки в браузере для просмотра интерфейса.
Исходный код отдельного локального клиента macOS 0.3.0 находится в
[`../skill-monitor-macos/`](../skill-monitor-macos/README.md); это отдельный локальный клиент.
Добавление зависимостей, нативного подключения и общего ядра ожидает независимого
ревью в изолированной среде. До выпуска нужны проверки на каждой целевой ОС.

## English

The interface is prepared for a future macOS, Windows and Linux client. It is
currently a page for presentation review, with no Tauri app or desktop binaries.
The native connection has not been implemented. Opening `index.html` gives the
page no access to computer folders; it does not scan or modify files.
Without a connection, component counts are unknown.

Any synthetic preview data consists of invented examples for interface review.
It does not come from files on your computer. Settings do not yet persist across
launches. No AI or antivirus connection is available.

The interface includes a findings filter that also covers informational
advisories. Folder help explains where to look and identifies `~/.agents` as
the default folder. This is guidance, not a result from reading your computer.
Invalid-configuration guidance points to the source path for manual JSON review.

Open `index.html` in this folder in a browser to review the interface.
The source for the separate local macOS 0.3.0 client is in
[`../skill-monitor-macos/`](../skill-monitor-macos/README.md); it is a separate local client.
Dependencies, the native connection and the shared core await an independent
review in an isolated environment. Each target OS needs testing before release.

## 简体中文

已为未来的 macOS、Windows 和 Linux 客户端准备界面。目前仅供审阅界面呈现，
尚无 Tauri 应用或桌面安装包。原生连接尚未实现。打开 `index.html` 不会让页面
访问电脑上的文件夹，也不会扫描或修改文件。未连接时，组件数量未知。

如显示模拟预览数据，这些是用于审阅界面的虚构示例，并非来自电脑上的文件。
尚未实现跨次启动保存设置。未连接 AI 或杀毒软件。

界面包含检查提示筛选，也涵盖信息性提示。文件夹帮助说明在哪里查找组件，
并注明默认文件夹 `~/.agents`。这是操作说明，并非读取电脑后得到的结果。
配置无效时，提示会指向源文件路径，供手动检查 JSON。

在浏览器中打开此文件夹内的 `index.html` 即可审阅界面。
独立本地 macOS 0.3.0 客户端的源代码位于
[`../skill-monitor-macos/`](../skill-monitor-macos/README.md)，是独立的本地客户端。
添加依赖、原生连接和共享核心前，仍需在隔离环境中进行独立审查。
发布前必须在每个目标操作系统上测试。

## Interface checks / Проверки интерфейса / 界面检查

From the repository root / Из корня репозитория / 在仓库根目录运行：

```sh
node clients/skill-monitor-desktop/tests/test.js
```

These checks do not replace native testing on each OS.
Эти проверки не заменяют тестирование нативного приложения на каждой ОС.
这些检查不能替代每个操作系统上的原生应用测试。
