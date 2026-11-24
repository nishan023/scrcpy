# Scrcpy Wireless Manager

[![Latest Release](https://img.shields.io/github/v/release/YOUR_USERNAME/YOUR_REPO?style=flat-square&color=06b6d4)](https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/YOUR_USERNAME/YOUR_REPO/total?style=flat-square&color=10b981)](https://github.com/YOUR_USERNAME/YOUR_REPO/releases)
[![Platform](https://img.shields.io/badge/platform-Windows%2010%2F11-0ea5e9?style=flat-square)](#requirements)

A single-file, zero-install Windows command-line dashboard for managing **[scrcpy](https://github.com/Genymobile/scrcpy)** over Wi-Fi (wireless ADB). Pair Android 11+ devices, switch USB-connected phones to wireless mode, launch normal/low-lag screen mirroring or audio-only streams, and reconnect in one keypress using persistent IP history.

> **Download Page:** [Open Web Download Page](https://YOUR_USERNAME.github.io/YOUR_REPO/) · **Releases:** [GitHub Releases](https://github.com/YOUR_USERNAME/YOUR_REPO/releases)

---

## Download

1. Go to the **[Latest Release](https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest)** page (or use the [Download Page](https://YOUR_USERNAME.github.io/YOUR_REPO/)).
2. Download **`Scrcpy-Wireless-Manager-v1.0.0.bat`** from the release assets.
3. Double-click the `.bat` file to launch.

> [!NOTE]
> Because this is an unsigned `.bat` script, Windows SmartScreen may show a warning on first run. Click **More info → Run anyway**, or inspect the plain-text source code directly before running.

---

## Features

- **Single-File Portable Script** — Hybrid `.bat` + PowerShell tool with no installation or external dependencies.
- **Auto-Detects `scrcpy`** — Automatically finds `scrcpy.exe` and `adb.exe` in the script folder, system `PATH`, `Downloads`, `Desktop`, or `Program Files`, with a built-in folder browser (`P`) if you want to pick a custom location.
- **Android 11+ Wireless Pairing** — Guided pairing using a 6-digit pairing code and pairing port, followed immediately by connection and mirroring.
- **USB-to-Wi-Fi Mode (Legacy TCP/IP)** — Detects a connected USB phone, auto-reads its `wlan0` Wi-Fi IP, enables `adb tcpip 5555`, verifies wireless connectivity, and starts mirroring so you can unplug the cable.
- **Multiple Mirroring & Audio Presets** — Normal mirroring, low-lag mirroring (`4M` / `1024px`), and audio-only streaming (Normal, `64K` Opus for weak Wi-Fi, `32K` Opus for very weak Wi-Fi).
- **Persistent Recent IP History** — Remembers up to 10 successful `IP:PORT` connections across restarts and exposes the top 4 (`H1`–`H4`) right on the dashboard for instant reconnection. Pairing ports are never saved.
- **Live Status & Stream Management** — Displays real-time ADB state (`Connected`, `Disconnected`, `Offline`, `Unauthorized`), tracks active manager-launched `scrcpy` windows, and lets you stop them individually or all at once.

---

## Dashboard Preview

```text
┌──────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                 SCRCPY WIRELESS MANAGER                                  [v1.0.0]│
│                 A command-line tool to manage scrcpy over Wi-Fi (wireless ADB)                   │
└──────────────────────────────────────────────────────────────────────────────────────────────────┘
 Active device: Connected  |  192.168.1.117:36977  |  Status: Streaming (1)
────────────────────────────────────────────────────────────────────────────────────────────────────
┌─ CONNECTION ──────────────────────────────────────────┐  ┌─ RECENT IP HISTORY ───────────────────┐
│ [1] Pair new phone (Android 11+)                      │  │ Previously used IP:PORT (quick connect│
│ [2] Connect / reconnect wireless debugging            │  │ ───────────────────────────────────── │
│ [3] Start wireless mirroring using USB                │  │ [H1] 192.168.1.117:36977   just now   │
│ [4] Reconnect USB-based wireless connection           │  │ [H2] 192.168.1.104:5555    2 hr ago   │
└───────────────────────────────────────────────────────┘  │ ───────────────────────────────────── │
┌─ SCREEN MIRRORING ────────────────────────────────────┐  │ Quick connect: H1-H4                  │
│ [5] Normal screen mirroring                           │  │ Custom IP:PORT: S                     │
│ [6] Low-lag screen mirroring                          │  │ Saved history: H                      │
└───────────────────────────────────────────────────────┘  │ History survives app restarts.        │
┌─ AUDIO STREAMING ─────────────────────────────────────┐  │ Pairing ports are never saved.        │
│ [7] Audio only - normal                               │  └───────────────────────────────────────┘
│ [8] Audio only - weak Wi-Fi (64K)                     │
│ [9] Audio only - very weak Wi-Fi (32K)                │
└───────────────────────────────────────────────────────┘
```

---

## Requirements

- **OS:** Windows 10 or Windows 11 (uses built-in Windows PowerShell)
- **scrcpy:** Extracted Windows release of [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy/releases) containing both `scrcpy.exe` and `adb.exe`
- **Android Device:**
  - Android 11+ for built-in **Wireless debugging** (and for audio forwarding)
  - Any Android version with **USB debugging** for USB-to-Wi-Fi mode (port `5555`)
  - Both PC and phone connected to the same Wi-Fi network

---

## Quick Start

### Option A: Android 11+ Wireless Debugging (No USB Needed)

1. On your phone, enable **Developer options** and turn on **Wireless debugging**.
2. Launch `Scrcpy-Wireless-Manager-v1.0.0.bat` and press **`1`** (*Pair new phone*).
3. On your phone, tap **Pair device with pairing code**.
4. Enter the **Pairing IP:PORT** and the **6-digit pairing code** shown on your phone.
5. Once paired, return to the main **Wireless debugging** screen, enter the **Connection IP:PORT** (note: this port is different from the pairing port), and mirroring starts automatically.

### Option B: USB-to-Wi-Fi (Port 5555)

1. Connect your phone via USB, unlock it, and enable **USB debugging** (accept the RSA prompt on your phone).
2. Press **`3`** (*Start wireless mirroring using USB*).
3. Confirm the auto-detected Wi-Fi IP address and enable TCP/IP mode on port `5555`.
4. Once connected, unplug the USB cable and enjoy wireless mirroring.

> [!WARNING]
> Legacy TCP/IP debugging on port `5555` accepts ADB connections over your local network. Only use it on a trusted private Wi-Fi network.

---

## Menu Reference

| Key | Category | Action | Scrcpy / ADB Flags |
| --- | --- | --- | --- |
| `1` | Connection | Pair new phone (Android 11+) | `adb pair <IP:PORT>` |
| `2` | Connection | Connect / reconnect wireless debugging | `adb connect <IP:PORT>` + `scrcpy` |
| `3` | Connection | Start wireless mirroring using USB | `adb -d tcpip 5555` + `scrcpy` |
| `4` | Connection | Reconnect USB-based wireless connection | Defaults port to `5555` |
| `5` | Screen Mirroring | Normal screen mirroring | `scrcpy -s <IP:PORT>` |
| `6` | Screen Mirroring | Low-lag screen mirroring | `--video-bit-rate=4M --max-size=1024` |
| `7` | Audio Streaming | Audio only — normal | `--no-video --no-control` |
| `8` | Audio Streaming | Audio only — weak Wi-Fi (64K) | `--no-video --no-control --audio-codec=opus --audio-bit-rate=64K --audio-buffer=200` |
| `9` | Audio Streaming | Audio only — very weak Wi-Fi (32K) | `--no-video --no-control --audio-codec=opus --audio-bit-rate=32K --audio-buffer=300` |
| `H1`–`H4` | Quick Connect | Connect to a saved recent `IP:PORT` | Uses history slot 1–4 |
| `D` | Device Management | List ADB devices | `adb devices -l` |
| `S` | Device Management | Select / change active device `IP:PORT` | Sets active device and connects |
| `X` | Device Management | Disconnect a specific device | `adb disconnect <IP:PORT>` |
| `A` | Device Management | Disconnect all wireless devices | `adb disconnect` |
| `C` | Device Management | Open Command Prompt in `scrcpy` folder | Launches `cmd /k` |
| `T` | Device Management | Stop manager-launched streams | Terminates selected or `ALL` streams |
| `R` | Device Management | Refresh live status | Re-queries ADB state |
| `H` | Device Management | Manage saved IP history | Remove entry or `CLEAR` all |
| `P` | Device Management | Change `scrcpy` installation path | Folder picker or manual path |
| `Q` | Device Management | Exit manager | Leaves active `scrcpy` windows open |

---

## Configuration & Storage

Settings and connection history are stored locally per user:

- **Config:** `%LOCALAPPDATA%\ScrcpyWirelessManager\config.json` (saved `scrcpy` folder path)
- **History:** `%LOCALAPPDATA%\ScrcpyWirelessManager\history.json` (up to 10 recent `IP:PORT` endpoints)

### ASCII Borders Mode

If your terminal font does not render Unicode box-drawing characters (`┌ ─ ┐`), set the `SCRCPY_ASCII` environment variable to `1` before launching:

```cmd
set SCRCPY_ASCII=1
Scrcpy-Wireless-Manager-v1.0.0.bat
```

---

## Troubleshooting

- **Connection fails after re-enabling Wireless debugging:** Android 11+ randomizes the connection port whenever Wireless debugging is toggled off and on. Check the main **Wireless debugging** screen on your phone for the new port and use option `2` or `S`.
- **Device shows `Unauthorized`:** Unlock your phone and accept the **Allow USB/Wireless debugging** prompt.
- **No audio in options `7`–`9`:** Audio forwarding requires Android 11 or newer and `scrcpy` v2.0+.
- **`scrcpy` not found:** Download the latest Windows archive from [Genymobile/scrcpy](https://github.com/Genymobile/scrcpy/releases), extract it, and select that folder using option `P`.

---

## Credits

Built as a lightweight Windows launcher around **[scrcpy](https://github.com/Genymobile/scrcpy)** by Genymobile.
