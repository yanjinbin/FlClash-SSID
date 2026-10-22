<div align="center">

<img src="assets/images/icon.png" alt="FlClash" width="88">

# FlClash

A multi-platform proxy client based on ClashMeta. Simple to use, open source and ad-free.

This is a personal fork of [FlClash](https://github.com/chen08209/FlClash) with extra desktop behaviour; see
[Fork changes](#fork-changes).

**English** · [简体中文](README_zh_CN.md)

[![Release](https://img.shields.io/github/v/release/yanjinbin/FlClash-SSID?style=flat-square&label=release)](https://github.com/yanjinbin/FlClash-SSID/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/yanjinbin/FlClash-SSID/total?style=flat-square&logo=github)](https://github.com/yanjinbin/FlClash-SSID/releases)
[![License](https://img.shields.io/github/license/yanjinbin/FlClash-SSID?style=flat-square)](LICENSE)

[Releases](https://github.com/yanjinbin/FlClash-SSID/releases/latest) · [Download](#download) · [Changelog](CHANGELOG.md) · [Build from source](#build-from-source)

</div>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="snapshots/preview-dark.png">
    <img alt="FlClash dashboard on a MacBook and a phone" src="snapshots/preview.png" width="92%">
  </picture>
</p>

## Features

- **One app for Android, Windows, macOS and Linux**, with x64 and ARM64 builds on the desktop.
- **mihomo (Clash.Meta) core** with rule routing, proxy groups, latency tests, system proxy and TUN mode.
- **Profiles** from a subscription link or a file, with a built-in editor, override scripts, and custom rules,
  proxies and proxy groups.
- **Live views** of connections, requests, DNS queries and logs.
- **Material You design with Apple-style interaction**: dynamic color, light and dark themes, continuous corners,
  sheets that snap between heights, and layouts that adapt from phones to desktops.
- **Backup and restore** through WebDAV or a local file.
- **Platform touches**: a Quick Settings tile, per-app proxy and Android TV support on Android; a tray menu and
  global hotkeys on the desktop.
- **Open source and ad-free**, licensed under GPL-3.0.

## Fork changes

- **Wi-Fi SSID rules.** Pick an outbound mode per SSID with a fallback for everything else (for example, direct at
  home and rules everywhere else). Native SSID events drive the switch, a short poll covers missed ones, the fallback
  applies before the new SSID is read, and existing connections are dropped so nothing keeps the previous mode.
- **Separate switches** for the system proxy and the TUN interface.
- **Dashboard cards** can be added and hidden in wide windows.
- **macOS menu bar icon** can be hidden.
- **Drag crash fix** on the desktop.

## Download

Get the latest build from [GitHub Releases](https://github.com/yanjinbin/FlClash-SSID/releases/latest).

| Platform | Packages | Notes |
| --- | --- | --- |
| Android | APK for `arm64-v8a`, `armeabi-v7a` and `x86_64` | Most phones use `arm64-v8a`. |
| Windows 10 and later | Installer (`.exe`) or portable `.zip`, for x64 and ARM64 | Pick ARM64 on Snapdragon and other ARM laptops. |
| macOS 12 and later | DMG for Apple Silicon and Intel | Also on Homebrew. |
| Linux | `.deb`, `.rpm` and AppImage, for x64 and ARM64 | See the tray note below. |

<p>
  <a href="https://github.com/yanjinbin/FlClash-SSID/releases/latest"><img alt="Get it on GitHub" src="snapshots/get-it-on-github.svg" height="56"></a>
</p>

**Homebrew**

```bash
brew install --cask yanjinbin/tap/flclash-ssid
```

**Linux tray icon**

The `.deb` package installs its own dependencies. With the AppImage or the `.rpm`, install the AyatanaAppIndicator
library so the tray icon can show:

```bash
sudo apt-get install libayatana-appindicator3-1   # Debian and Ubuntu
sudo dnf install libayatana-appindicator-gtk3     # Fedora
```

## Usage

**Import a profile from a link.** Opening a link in this form imports the subscription into FlClash. The `clashmeta://`
and `flclash://` schemes work the same way.

```text
clash://install-config?url=<URL-encoded subscription link>
```

**Automate on Android.** Tasker, MacroDroid and similar apps can start, stop or toggle the proxy by starting an
activity with one of these actions:

```text
com.follow.clash.action.START
com.follow.clash.action.STOP
com.follow.clash.action.TOGGLE
```

From a computer, the same works over adb:

```bash
adb shell am start -a com.follow.clash.action.TOGGLE
```

## Build from source

You need [Flutter](https://docs.flutter.dev/get-started/install) 3.47 (release builds use 3.47.6),
[Go](https://go.dev/dl/) 1.27 and [Rust](https://rustup.rs/) installed through rustup. Each platform builds on its own
host, except Android, which builds anywhere.

```bash
git clone --recursive https://github.com/yanjinbin/FlClash-SSID.git
cd FlClash-SSID
flutter pub get
dart setup.dart android   # or windows, macos, linux
```

Packages land in `dist/`. The Go core and the Rust libraries are compiled as part of the Flutter build.

| Platform | Also needed |
| --- | --- |
| Android | Android SDK with the NDK. Add `--arch arm64` to build a single ABI. |
| Windows | GCC (MinGW-w64) for the core and [Inno Setup](https://jrsoftware.org/isinfo.php) 6 for the installer. |
| macOS | Xcode and Node.js. The script installs `appdmg` through npm. |
| Linux | Debian or Ubuntu. The script installs the build packages with apt and downloads `appimagetool`. |

Run `dart setup.dart --help` for the remaining options, such as `--targets` to build only some package formats.

## Support

Bugs and feature requests go to [GitHub Issues](https://github.com/yanjinbin/FlClash-SSID/issues). The upstream
project lives at [chen08209/FlClash](https://github.com/chen08209/FlClash).

## License

FlClash is released under the [GPL-3.0 license](LICENSE), and this fork keeps the same license.
