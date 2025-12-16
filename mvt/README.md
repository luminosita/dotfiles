# Mobile Verification Toolkit (MVT) - Device Analysis

Automated forensic analysis of Android devices for spyware and malware detection using the Mobile Verification Toolkit.

## Quick Start

```bash
# Run analysis on all connected devices
./mvt-analyze.sh

# Analyze specific devices only
./mvt-analyze.sh --devices 13cdaf90,29021FDH2007L1

# Skip IOC download (use cached indicators)
./mvt-analyze.sh --skip-iocs

# Show help
./mvt-analyze.sh --help
```

## Requirements

- **adb** (Android Debug Bridge) - included in Android SDK Platform Tools
- **pipx** - for Python package management
- **Python 3.7+** - for running MVT

## Setup

### 1. Install adb (if not already installed)

**macOS:**
```bash
brew install android-platform-tools
```

**Linux:**
```bash
sudo apt install android-tools-adb  # Ubuntu/Debian
sudo dnf install android-tools      # Fedora
sudo pacman -S android-tools        # Arch
```

### 2. Enable USB Debugging on Android Device

1. Go to Settings → About Phone
2. Tap "Build Number" 7 times to enable Developer Options
3. Go to Settings → Developer Options
4. Enable "USB Debugging"
5. Connect device via USB

### 3. Install MVT (Automatic)

The script will automatically install MVT if not present. Manual installation:

```bash
pipx install 'mvt[android]'
```

## Usage

### Basic Analysis

```bash
cd /path/to/dotfiles/mvt
./mvt-analyze.sh
```

This will:
1. ✓ Check for adb availability
2. ✓ Detect all connected Android devices
3. ✓ Install/update MVT if needed
4. ✓ Download latest Indicators of Compromise (IOCs)
5. ✓ Extract forensic data from each device
6. ✓ Generate threat analysis reports
7. ✓ Save results to `./out/device-<SERIAL>/`

### Options

#### `--skip-iocs`
Skip downloading/updating IOCs. Useful if you've recently downloaded them or are offline.

```bash
./mvt-analyze.sh --skip-iocs
```

#### `--devices SERIAL1,SERIAL2`
Analyze only specific devices instead of all connected devices.

```bash
./mvt-analyze.sh --devices 13cdaf90,29021FDH2007L1
```

#### `--help`
Display help message.

```bash
./mvt-analyze.sh --help
```

## Output Structure

Results are organized in `./out/` directory:

```
./out/
├── device-13cdaf90/
│   ├── ANALYSIS_REPORT.md      # Threat assessment report
│   ├── device_info.txt         # Device properties & Android version
│   ├── packages.txt            # User-installed applications
│   ├── packages_system.txt     # System packages
│   ├── processes.txt           # Running processes
│   ├── selinux_status.txt      # Security context
│   └── logcat.txt              # System logs
│
└── device-29021FDH2007L1/
    └── [same files as above]
```

## IOC Verification Method

This script follows **MVT's official IOC checking procedures** as recommended at https://docs.mvt.re/en/latest/iocs/:

1. **Downloads official IOCs** using `mvt-android download-iocs`
2. **Stores them in MVT's application directory** (auto-loaded by MVT)
3. **Checks extracted data** against 10,885+ STIX2 indicators using `mvt-android check-iocs`
4. **Generates threat assessment** based on official MVT findings

**Note:** For optimal results, ensure IOCs are regularly updated with `mvt-android download-iocs`

## What Gets Analyzed

### Spyware Campaigns

The analysis checks your device against 10,885+ official indicators for:

- **NSO Group Pegasus** - Zero-click mobile spyware
- **Predator Spyware** - Commercial mobile surveillance
- **RCS Lab Spyware** - Italian spyware vendor
- **Stalkerware** - Domestic surveillance tools
- **Candiru (DevilsTongue)** - Commercial spyware
- **WyrmSpy & DragonEgg** - iOS/Android spyware
- **Quadream KingSpawn** - Mobile surveillance toolkit
- **Operation Triangulation** - iOS exploitation
- **Wintego Helios** - Surveillance suite
- **NoviSpy (Serbia)** - Surveillance implant

### Data Extracted

For each device:
- **Device Information** - Model, OS version, build properties
- **Installed Applications** - All user and system packages
- **Running Processes** - Currently executing processes
- **Security Settings** - SELinux status and policies
- **System Logs** - Last logcat entries

## Output Reports

Each device gets an `ANALYSIS_REPORT.md` containing:

- ✓ Threat assessment summary
- ✓ Device security posture
- ✓ Indicators of Compromise check
- ✓ System integrity verification
- ✓ Security recommendations
- ✓ Data files generated

## Troubleshooting

### No devices found

```bash
# Check if adb daemon is running
adb devices

# If no devices appear:
# 1. Check USB connection (try different cable/port)
# 2. On phone: Accept USB debugging prompt
# 3. Ensure Developer Options → USB Debugging is ON
# 4. Try: adb kill-server && adb devices
```

### adb: command not found

Install Android SDK Platform Tools:

```bash
# macOS
brew install android-platform-tools

# Or add to PATH if already installed
export PATH=$PATH:~/Library/Android/sdk/platform-tools
```

### MVT not installing

Ensure pipx is installed:

```bash
pip install --user pipx
export PATH=$PATH:~/.local/bin
```

Then run the script again.

### No IOC downloads

If downloads are failing, try skipping and using cached IOCs:

```bash
./mvt-analyze.sh --skip-iocs
```

Or manually download:

```bash
mvt-android download-iocs
```

## Device Preparation

### Enable USB Debugging

1. **Settings** → **About Phone**
2. Tap **Build Number** 7 times
3. **Settings** → **Developer Options**
4. Enable **USB Debugging**
5. When prompted, allow debugging on this computer

### Disable USB Debugging After Analysis

For security, disable USB Debugging when not in use:

1. **Settings** → **Developer Options**
2. Toggle **USB Debugging** OFF

## Performance

Analysis time depends on device:
- **Small device** (200-300 apps): 2-5 minutes
- **Medium device** (400-600 apps): 5-10 minutes
- **Large device** (700+ apps): 10-15 minutes

Logcat extraction is the longest operation.

## Security Notes

⚠️ **USB Debugging Enables Full Device Access**

When USB Debugging is enabled, anyone with USB access to your device can:
- Extract all data
- Install apps
- Execute commands
- Access private files

**Always disable USB Debugging when not needed.**

## Legal & Privacy

This tool is for:
- ✓ Personal security verification
- ✓ Authorized mobile forensics
- ✓ Security research
- ✓ Incident response

**Never use on devices you don't own or have authorization to analyze.**

## Resources

- [Mobile Verification Toolkit Docs](https://docs.mvt.re/)
- [Android Security Best Practices](https://support.google.com/android/answer/9720847)
- [Amnesty International IOCs](https://github.com/AmnestyTech/investigations)
- [MVT Indicators Project](https://github.com/mvt-project/mvt-indicators)

## Support

For issues with:
- **This script**: Check the [dotfiles GitHub](https://github.com/anthropics/claude-code/issues)
- **MVT tool**: See [MVT Documentation](https://docs.mvt.re/)
- **Android issues**: Consult [Android Debug Bridge docs](https://developer.android.com/tools/adb)
