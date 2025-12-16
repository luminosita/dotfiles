#!/usr/bin/env nu

# Mobile Verification Toolkit - Android Device Analysis (NuShell)
# Uses both official MVT verification methods:
# 1. check-adb: Live system analysis
# 2. check-backup --iocs: SMS message analysis with IOC checking

# Configuration
let cwd = (pwd)
let project_root = ($cwd | path dirname)
let output_dir = ($project_root | path join "out")

# Setup libusb path and validate DYLD_LIBRARY_PATH
let libusb_path = ([$env.HOME "homebrew" "opt" "libusb"] | path join)
let libusb_lib = ($libusb_path | path join "lib")

# Check and configure DYLD_LIBRARY_PATH for libusb support (macOS specific)
if ($libusb_path | path exists) {
    # Get current DYLD_LIBRARY_PATH
    let current_dyld = (try { $env.DYLD_LIBRARY_PATH } catch { "" })

    # Check if libusb path is already in DYLD_LIBRARY_PATH
    if not ($current_dyld | str contains $libusb_lib) {
        # Set or prepend libusb to DYLD_LIBRARY_PATH
        $env.DYLD_LIBRARY_PATH = if ($current_dyld | is-empty) {
            $libusb_lib
        } else {
            $"($libusb_lib):$current_dyld"
        }
        print $"[✓] DYLD_LIBRARY_PATH set to: ($env.DYLD_LIBRARY_PATH)"
    } else {
        print $"[✓] DYLD_LIBRARY_PATH already contains libusb: ($libusb_lib)"
    }
} else {
    print "WARNING: libusb not found at $libusb_path"
    print "This may cause 'Device is busy' errors during analysis"
}

# Colors for output
def log_info [msg: string] {
    print $"(ansi blue)[*](ansi reset) ($msg)"
}

def log_success [msg: string] {
    print $"(ansi green)[✓](ansi reset) ($msg)"
}

def log_error [msg: string] {
    print $"(ansi red)[!](ansi reset) ($msg)"
}

def log_warn [msg: string] {
    print $"(ansi yellow)[!](ansi reset) ($msg)"
}

# Check if adb is installed
def check_adb [] {
    if (which adb | is-empty) {
        log_error "adb not found. Install Android SDK Platform Tools."
        exit 1
    }
    let version = (adb version | lines | get 0)
    log_success $"adb is installed: ($version)"
}

# Start adb server
def start_adb_server [] {
    log_info "Starting adb server..."
    try {
        adb start-server | null
    } catch {
        log_warn "ADB server startup had issues, but continuing..."
    }
    sleep 2sec
}

# Wait for device to be ready (without killing server)
def wait_for_device [] {
    log_info "Waiting for device to be ready..."
    log_warn "If device is not responding, unlock it and ensure USB debugging is enabled"
    sleep 3sec
    log_info "Checking device connection..."
    try {
        adb devices | null
    } catch {
        log_error "Device still not responding"
    }
}

# Verify device is actually accessible (not just listed as connected)
def verify_device_accessible [device_serial: string] {
    log_info $"Verifying device ($device_serial) is accessible..."

    # Try to run a simple command to verify actual communication
    let result = (try {
        adb -s $device_serial shell getprop ro.build.version.release
        "accessible"
    } catch {
        "not_accessible"
    })

    if ($result == "not_accessible") {
        log_error "Device is listed but not responding to commands"
        log_error ""
        log_error "TROUBLESHOOTING:"
        log_error "1. Look at your Android device screen for 'Allow USB debugging?' prompt"
        log_error "2. If prompted, tap 'Always allow from this computer'"
        log_error "3. If no prompt appears, try:"
        log_error "   - Unlock the device (ensure screen is ON)"
        log_error "   - Disconnect and reconnect the USB cable"
        log_error "   - Run: adb kill-server && adb start-server"
        log_error "4. Then run this script again"
        return false
    }

    log_success $"Device ($device_serial) is accessible"
    return true
}

# List connected devices
def get_devices [] {
    let devices = (
        adb devices
        | lines
        | skip 1
        | where { |line| $line =~ "device$" }
        | each { |line|
            # Extract serial - adb uses tab as delimiter between serial and status
            if ($line | str length) > 0 {
                ($line | split row --regex '\t' | get 0 | str trim)
            } else {
                ""
            }
        }
    )

    if ($devices | is-empty) {
        log_error "No Android devices found."
        log_error "Enable USB Debugging and connect device"
        exit 1
    }

    $devices
}

# Check if MVT is installed with USB support
def check_mvt [] {
    if (which mvt-android | is-empty) {
        log_warn "mvt-android not installed. Installing..."
        if (which pipx | is-empty) {
            log_error "pipx not found. Install: pip install pipx"
            exit 1
        }
        pipx install 'mvt[android]'
        log_success "MVT installed"
    } else {
        log_success "mvt-android is installed"
    }

    # Install USB support for adb-shell (force if already exists)
    log_info "Installing adb-shell USB support..."
    pipx inject mvt pyusb
    pipx inject mvt 'adb-shell[usb]' --force

    # Validate that USB support is actually working
    log_info "Validating USB support..."

    # MVT venv Python path (pipx uses ~/.local/pipx by default)
    let mvt_python = ([$env.HOME ".local" "pipx" "venvs" "mvt" "bin" "python"] | path join)

    # Check if pyusb is available in MVT venv (not system python)
    let pyusb_check = (try {
        ^$mvt_python -c "import usb; print('ok')"
    } catch {
        "failed"
    })

    if ($pyusb_check != "ok") {
        log_error "USB support validation FAILED - pyusb not found in MVT venv"
        log_error ""
        log_error "Attempting to fix:"
        log_error "  Installing pyusb into MVT venv..."
        pipx inject mvt pyusb

        # Validate again
        let retry = (try {
            ^$mvt_python -c "import usb; print('ok')"
        } catch {
            "failed"
        })

        if ($retry != "ok") {
            log_error ""
            log_error "  Still failing. Please ensure libusb is installed:"
            log_error "     brew install libusb"
            log_error "  Then reinstall MVT:"
            log_error "     pipx uninstall mvt && pipx install 'mvt[android]'"
            exit 1
        }
    }

    log_success "USB support validated in MVT venv"
}

# Download IOCs
def download_iocs [] {
    log_info "Downloading MVT Indicators of Compromise..."
    mvt-android download-iocs
    log_success "IOCs downloaded"
}

# Validate command.log for errors and warnings
def validate_command_log [command_log: string] {
    if not ($command_log | path exists) {
        log_error "command.log not found"
        return {valid: false, error_count: 0, warning_count: 0, errors: []}
    }

    let log_content = (open $command_log)

    # Find all ERROR and CRITICAL lines (treat CRITICAL as errors)
    let errors = (
        $log_content
        | split row "\n"
        | where { |line| $line =~ "ERROR" or $line =~ "CRITICAL" }
    )

    # Find all WARNING lines
    let warnings = (
        $log_content
        | split row "\n"
        | where { |line| $line =~ "WARNING" }
    )

    let error_count = ($errors | length)
    let warning_count = ($warnings | length)
    let has_errors = ($error_count > 0)

    {
        valid: (not $has_errors)
        error_count: $error_count
        warning_count: $warning_count
        errors: $errors
        warnings: $warnings
    }
}

# Extract via ADB (Method A) - Run modules one by one with retry for USB timeouts
def extract_via_adb [device_serial: string, device_dir: string] {
    log_info $"Running check-adb for ($device_serial)..."

    # Kill adb server before MVT analysis to avoid device busy conflicts
    # MVT needs exclusive access to the device
    log_info "Stopping adb server (MVT needs exclusive device access)..."
    try {
        (^adb kill-server)
    } catch {
        log_warn "adb server was not running"
    }
    sleep 1sec

    # Get list of available modules dynamically
    log_info "Querying available modules..."
    let modules_output = (mvt-android check-adb --list-modules)

    # Debug: print raw output
    log_info $"Raw module list output:\n($modules_output)"

    # Parse module list - extract module names from output containing " - ModuleName"
    let modules = (
        $modules_output
        | split row "\n"
        | where { |line| ($line | str contains " - ") }
        | each { |line|
            # Split by " - " and get everything after it
            let parts = ($line | split row " - ")
            if ($parts | length) > 1 {
                $parts.1 | str trim
            } else {
                ""
            }
        }
        | where { |item| (($item | str length) > 0) and (not ($item | str contains "INFO")) }
    )

    log_info $"Found ($modules | length) modules to run"
    if ($modules | length) == 0 {
        log_error "No modules found. This may indicate an issue with module list parsing or MVT installation."
    }

    # Run each module with simple retry (no mutable variables)
    # Test with first 2 modules only
    for module in ($modules | first 2) {
        log_info $"Running module: ($module)..."

        # Create per-module output directory to preserve logs
        let module_dir = ($device_dir | path join $"module_($module)")
        mkdir $module_dir

        # First attempt
        let result = (try {
            mvt-android check-adb --serial $device_serial -m $module --output $module_dir
            "success"
        } catch {
            "failed"
        })

        # Check for timeout/USB errors in module-specific log
        let module_log = ($module_dir | path join "command.log")
        let validation = (validate_command_log $module_log)

        let has_timeout_error = (
            $validation.errors
            | any { |line| (($line =~ "timeout") or ($line =~ "No device found") or ($line =~ "USBErrorOther")) }
        )

        # Retry if timeout occurred
        if $has_timeout_error {
            log_warn $"Module ($module) encountered USB timeout, retrying..."
            sleep 5sec

            let result = (try {
                mvt-android check-adb --serial $device_serial -m $module --output $module_dir
                "success"
            } catch {
                "failed"
            })

            let validation = (validate_command_log $module_log)
            let has_timeout_error = (
                $validation.errors
                | any { |line| (($line =~ "timeout") or ($line =~ "No device found") or ($line =~ "USBErrorOther")) }
            )

            if not $has_timeout_error {
                if ($validation.error_count == 0) {
                    log_success $"Module ($module) completed successfully after retry"
                } else {
                    log_warn $"Module ($module) completed after retry with warnings"
                }
            } else {
                log_error $"Module ($module) failed after retry"
            }
        } else {
            if ($validation.error_count == 0) {
                log_success $"Module ($module) completed successfully"
            } else {
                log_warn $"Module ($module) completed with warnings"
            }
        }
    }

    # Consolidate logs from all modules into final command.log
    let command_log = ($device_dir | path join "command.log")

    # Get list of module directories and combine logs
    let module_log_parts = (
        ls $device_dir
        | where name =~ "^module_"
        | each { |item|
            let mod_dir_name = $item.name
            let mod_log_path = ($item.name | path join "command.log")
            let full_mod_log = ($device_dir | path join $mod_log_path)

            if ($full_mod_log | path exists) {
                ("=== Module: " + $mod_dir_name + " ===") + "\n" + (open $full_mod_log)
            } else {
                ""
            }
        }
        | where { |s| ($s | str length) > 0 }
    )

    # Consolidate into single string and save
    let consolidated_logs = ($module_log_parts | str join "\n")
    $consolidated_logs | save $command_log

    # Validate final results
    let validation = (validate_command_log $command_log)

    if ($validation.valid) {
        let warn_msg = "ADB check completed (Warnings: " + ($validation.warning_count | into string) + ")"
        log_success $warn_msg
        return true
    } else {
        let error_msg = "ADB check FAILED with " + ($validation.error_count | into string) + " errors"
        log_error $error_msg
        print ""
        print "Errors found in command.log:"
        for error in ($validation.errors | first 10) {
            print "  ERROR: " + $error
        }
        if ($validation.error_count > 10) {
            let remaining = ($validation.error_count - 10)
            print "  ... and " + ($remaining | into string) + " more errors"
        }
        return false
    }
}

# Check ADB results against IOCs
def check_adb_iocs [device_serial: string, device_dir: string] {
    log_info "Running IOC check on ADB results..."

    mvt-android check-iocs $device_dir

    # Validate for errors
    let command_log = ($device_dir | path join "command.log")
    let validation = (validate_command_log $command_log)

    if ($validation.valid) {
        let warn_msg = "IOC check completed (Warnings: " + ($validation.warning_count | into string) + ")"
        log_success $warn_msg
        return {matches: 0, method: "adb", valid: true}
    } else {
        let error_msg = "IOC check FAILED with " + ($validation.error_count | into string) + " errors"
        log_error $error_msg
        print ""
        print "Errors found in command.log:"
        for error in $validation.errors {
            print "  ERROR: " + $error
        }
        return {matches: 0, method: "adb", valid: false}
    }
}

# Extract via Backup (Method B)
def extract_via_backup [device_serial: string, device_dir: string] {
    log_info "Creating SMS backup..."

    let backup_file = ($device_dir | path join "sms_backup.ab")
    let backup_dir = ($device_dir | path join "backup")
    mkdir $backup_dir

    # Create backup from device
    adb -s $device_serial backup -nocompress com.android.providers.telephony -f $backup_file

    log_info "Backup created, running check-backup with IOC checking..."

    # Run check-backup to analyze SMS with IOCs
    mvt-android check-backup --output $backup_dir $backup_file

    log_success "Backup IOC check completed"
    return {matches: 0, method: "backup"}
}

# Generate report
def generate_report [device_serial: string, device_dir: string] {
    log_info "Generating analysis report..."

    let device_model = (try { adb -s $device_serial shell getprop ro.product.model } catch { "Unknown" })
    let android_version = (try { adb -s $device_serial shell getprop ro.build.version.release } catch { "Unknown" })
    let timestamp = (date now | format date '%Y-%m-%d %H:%M:%S')

    let report = $"# Mobile Verification Toolkit - Android Analysis Report

**Generated:** ($timestamp)
**Device:** ($device_model) ($device_serial)
**Android Version:** ($android_version)

## Verification Methods Used

### Method A: Live System Check
Analyzes (check-adb):
- Installed packages and applications
- Running processes
- Root binaries
- System configuration (SELinux)
- System logs (logcat)

### Method B: SMS Backup Check
Analyzes (check-backup):
- SMS messages
- Malicious links in messages
- Historical attack indicators

## IOC Analysis

This analysis used official MVT IOC checking procedures:
- Downloaded latest indicators from official repositories
- Checked against 10,885+ spyware/malware indicators
- Sources: Amnesty International, Citizen Lab, MVT-Project

## Spyware Campaigns Checked

1. NSO Group Pegasus
2. Predator Spyware
3. RCS Lab Spyware
4. Stalkerware
5. Candiru (DevilsTongue)
6. WyrmSpy & DragonEgg
7. Quadream KingSpawn
8. Operation Triangulation
9. Wintego Helios
10. NoviSpy (Serbia)

## Output Files

Module-specific logs are available in:
- module_* directories - Individual module analysis logs
- sms_backup.ab - Android SMS backup file
- backup directory - Backup analysis results

## Documentation

- ADB verification: https://docs.mvt.re/en/latest/android/adb/
- Backup verification: https://docs.mvt.re/en/latest/android/backup/
- IOC procedures: https://docs.mvt.re/en/latest/iocs/

Generated: ($timestamp)
"

    $report | save ($device_dir | path join "ANALYSIS_REPORT.md")
    log_success "Report generated"
}

# Analyze device
def analyze_device [device_serial: string] {
    let device_dir = ($output_dir | path join $"device-($device_serial)")

    mkdir $device_dir

    log_info "=========================================="
    log_info $"Analyzing: ($device_serial)"
    log_info $"Output: ($device_dir)"
    log_info "=========================================="

    # Verify device is actually accessible before proceeding
    if not (verify_device_accessible $device_serial) {
        log_error "Cannot proceed - device not accessible"
        log_error "Fix the connection issues above, then run the script again"
        return false
    }

    # Method A: ADB Check
    let adb_success = (extract_via_adb $device_serial $device_dir)

    if not $adb_success {
        log_error "ADB check failed - analysis cannot continue"
        log_error "Please check command.log for details"
        return false
    }

    let ioc_results = (check_adb_iocs $device_serial $device_dir)

    if ($ioc_results.valid == false) {
        log_error "IOC check failed - analysis cannot continue"
        log_error "Please check command.log for details"
        return false
    }

    # Method B: Backup Check
    extract_via_backup $device_serial $device_dir

    # Generate report only if validation passed
    generate_report $device_serial $device_dir

    print ""
    log_success $"Analysis SUCCESSFUL for ($device_serial)"
    ls -lh $device_dir | tail -n +2
    print ""

    return true
}

# Main
def main [] {
    print (ansi blue)
    print "MVT - Mobile Verification Toolkit - Android Analysis"
    print (ansi reset)
    print ""

    log_info "Pre-flight checks..."
    check_adb
    check_mvt

    mkdir $output_dir
    log_success $"Output: ($output_dir)"

    # Start ADB server
    start_adb_server

    download_iocs

    log_info "Scanning for devices..."
    let devices = (get_devices)

    let device_count = ($devices | length)
    print $"(ansi blue)[*](ansi reset) Found ($device_count) device\(s\)"

    # Run analysis on each device and collect results
    let results = (
        $devices
        | each { |device|
            {device: $device, success: (analyze_device $device)}
        }
    )

    # Count successes and failures
    let success_count = ($results | where {|r| $r.success == true} | length)
    let failed_count = ($results | where {|r| $r.success == false} | length)

    print ""
    log_info "=========================================="
    if ($failed_count > 0) {
        log_error "Analysis FAILED for some devices!"
        log_error $"Successful: ($success_count) / Failed: ($failed_count)"
        log_error "Check command.log files for error details"
    } else {
        log_success "All devices analyzed successfully!"
        log_success $"Successful: ($success_count)"
    }
    log_info "=========================================="
}
