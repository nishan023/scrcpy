# Scrcpy Wireless Manager

[![Release v1.0.0](assets/badge-release.svg)](https://github.com/nishan023/scrcpy/releases/tag/v1.0.0)
[![Platform Windows 10/11](assets/badge-windows.svg)](#requirements)
[![Portable .bat](assets/badge-portable.svg)](https://github.com/nishan023/scrcpy/releases/download/v1.0.0/Scrcpy-Wireless-Manager-v1.0.0.bat)

A single-file Windows 10/11 CLI dashboard for managing **[scrcpy](https://github.com/Genymobile/scrcpy)** over Wi-Fi (wireless ADB).

**[Download Website](https://scrcpy.dhakalnishan.com.np/)** · **[Latest Release (`v1.0.0`)](https://github.com/nishan023/scrcpy/releases/tag/v1.0.0)** · **[All Releases](https://github.com/nishan023/scrcpy/releases)**

---

## Quick Run (PowerShell)

Open **PowerShell as Administrator** and run:

```powershell
# SCRCPY Wireless Manager
irm https://get.dhakalnishan.com.np/scrcpy | iex
```

### Or Download Manually

1. Download **`Scrcpy-Wireless-Manager-v1.0.0.bat`** from the **[v1.0.0 release](https://github.com/nishan023/scrcpy/releases/download/v1.0.0/Scrcpy-Wireless-Manager-v1.0.0.bat)** or **[scrcpy.dhakalnishan.com.np](https://scrcpy.dhakalnishan.com.np/)**.
2. Double-click the `.bat` file to run (no install needed).

> [!NOTE]
> If Windows SmartScreen warns about an unsigned `.bat` script, click **More info → Run anyway**.

---

## Requirements

- **Windows 10 / 11** (uses built-in PowerShell)
- **[scrcpy for Windows](https://github.com/Genymobile/scrcpy/releases)** extracted anywhere (auto-detected on launch)
- **Android phone** on the same Wi-Fi network (Android 11+ for Wireless debugging & audio)

---

## Features

- **Android 11+ Wireless Pairing** — Pair with a 6-digit code and connect directly.
- **USB-to-Wi-Fi Setup** — Auto-detects phone IP, enables `adb tcpip 5555`, and switches to wireless.
- **Mirroring & Audio Presets** — Normal, low-lag (`4M` / `1024px`), and audio-only (Normal, `64K`, `32K` Opus).
- **Quick-Connect History** — Saves up to 10 recent `IP:PORT` connections (`H1`–`H4` for 1-key reconnect).
- **Live Controls** — Shows live ADB status, manages active streams, and opens CMD in your `scrcpy` folder.

---

## Shortcuts

| Key | Action |
| --- | --- |
| `1` / `2` | Pair new phone (Android 11+) / Connect wireless debugging |
| `3` / `4` | Start wireless via USB (`5555`) / Reconnect USB-based wireless |
| `5` / `6` | Normal mirroring / Low-lag mirroring (`4M`, `1024px`) |
| `7` / `8` / `9` | Audio only — Normal / `64K` / `32K` (weak Wi-Fi) |
| `H1`–`H4` | Quick-connect from recent IP history |
| `D` `S` `X` `A` | List devices / Select IP / Disconnect one / Disconnect all |
| `T` `C` `H` `P` | Stop streams / Open CMD / Manage history / Change `scrcpy` path |
| `R` / `Q` | Refresh status / Exit |

---

## Notes

- Settings and history are saved in `%LOCALAPPDATA%\ScrcpyWirelessManager\`.
- Run with `set SCRCPY_ASCII=1` if your terminal font does not render box-drawing characters.
- Built around **[Genymobile/scrcpy](https://github.com/Genymobile/scrcpy)**.
