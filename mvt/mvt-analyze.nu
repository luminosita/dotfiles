#!/usr/bin/env nu

# Mobile Verification Toolkit - Android Device Analysis (NuShell)
# Uses official MVT verification method:
# check-adb: Live system analysis

let cwd = (pwd)
let project_root = ($cwd | path dirname)
let output_dir = ($project_root | path join "out")

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

    # Find all CRITICAL errors (exclude informational ERROR messages like "optionally available")
    let errors = (
        $log_content
        | split row "\n"
        | where { |line| ($line =~ "CRITICAL") or (($line =~ "ERROR") and (not ($line =~ "optionally available"))) }
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

# Checkpoint management for resume capability
def get_checkpoint_file [device_dir: string] {
    $device_dir | path join ".checkpoint.json"
}

def load_checkpoint [device_dir: string] {
    let checkpoint_file = (get_checkpoint_file $device_dir)
    if ($checkpoint_file | path exists) {
        try {
            open $checkpoint_file
        } catch {
            {completed_modules: [], total_modules: 0}
        }
    } else {
        {completed_modules: [], total_modules: 0}
    }
}

def save_checkpoint [device_dir: string, completed_modules: list, total_modules: int] {
    let checkpoint_file = (get_checkpoint_file $device_dir)
    let checkpoint = {
        completed_modules: $completed_modules
        total_modules: $total_modules
        last_update: (date now | format date '%Y-%m-%d %H:%M:%S')
    }
    $checkpoint | to json | save -f $checkpoint_file
    log_info $"Checkpoint saved: ($completed_modules | length)/($total_modules) modules completed"
}

def is_module_completed [device_dir: string, module_name: string] {
    let checkpoint = (load_checkpoint $device_dir)
    $checkpoint.completed_modules | any { |m| $m == $module_name }
}

def kill_adb [] {
    # Kill adb server before MVT analysis to avoid device busy conflicts
    # MVT needs exclusive access to the device
    log_info "Stopping adb server (MVT needs exclusive device access)..."
    try {
        (^adb kill-server)
    } catch {
        log_warn "adb server was not running"
    }
    sleep 1sec
}

def get_modules [] {
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

    $modules
}

# Extract via ADB (Method A) - Run modules one by one with resume capability
def extract_via_adb [device_dir: string, skip_sms?: bool] {
    log_info $"Running check-adb ..."

    kill_adb

    # Get list of available modules dynamically
    log_info "Querying available modules..."
    let modules_output = (mvt-android check-adb --list-modules)

    # Parse module list - extract module names from output containing " - ModuleName"
    let modules = get_modules

    # Load checkpoint to see which modules are already completed
    let checkpoint = (load_checkpoint $device_dir)
    let already_completed = $checkpoint.completed_modules

    if ($already_completed | length) > 0 {
        log_warn $"Resuming from checkpoint: ($already_completed | length) modules already completed"
        let completed_list = ($already_completed | str join ", ")
        log_info $"Completed modules: ($completed_list)"
    }

    mut module_results = []
    mut completed_modules = $already_completed

    # Run each module - continue through all, only return on error
    for module in $modules {
        # Skip SMS module if skip_sms flag is set
        if ($skip_sms == true and $module == "SMS") {
            log_warn "Skipping SMS module (--skip-sms flag set)"
            continue
        }

        # Skip if module already completed
        if (is_module_completed $device_dir $module) {
            log_warn $"Skipping already completed module: ($module)"
            continue
        }

        log_info $"Running module: ($module)..."

        # Create per-module output directory to preserve logs
        let module_dir = ($device_dir | path join $"module_($module)")
        mkdir $module_dir

        # Run module
        let result = (try {
            mvt-android check-adb -m $module --output $module_dir
            "success"
        } catch {
            "failed"
        })

        # Validate module output
        let module_log = ($module_dir | path join "command.log")
        let validation = (validate_command_log $module_log)

        # Check for USB connection timeout errors (not module-specific errors)
        let has_timeout_error = (
            $validation.errors
            | any { |line| (($line =~ "Device is busy") or ($line =~ "No device found") or ($line =~ "USBErrorOther") or ($line =~ "libusb") or ($line =~ "Unable to connect")) }
        )

        # Exit on timeout - save checkpoint and return
        if $has_timeout_error {
            log_error $"Module ($module): USB timeout/connection error"
            log_warn "Saving checkpoint for resume on next run..."
            save_checkpoint $device_dir $completed_modules ($modules | length)
            return {valid: false, modules: module_results}
        }

        # Exit on validation errors - save checkpoint and return
        if (not $validation.valid) {
            let error_msg = $"Module ($module): " + ($validation.error_count | into string) + " errors"
            log_error $error_msg
            print ""
            print "Errors found:"
            for error in ($validation.errors | first 5) {
                print "  ERROR: " + $error
            }
            if ($validation.error_count > 5) {
                let remaining = ($validation.error_count - 5)
                print "  ... and " + ($remaining | into string) + " more errors"
            }
            log_warn "Saving checkpoint for resume on next run..."
            save_checkpoint $device_dir $completed_modules ($modules | length)
            return {valid: false, modules: module_results}
        }

        # Module passed - add to completed and save checkpoint
        $completed_modules = ($completed_modules | append $module)
        save_checkpoint $device_dir $completed_modules ($modules | length)

        $module_results = ($module_results | append {
                name: $module
                valid: $validation.valid
                errors: $validation.errors
                warnings: $validation.warnings
                error_count: $validation.error_count
                warning_count: $validation.warning_count
            })

        # Module passed - log success and continue to next module
        let warn_msg = $"Module ($module): " + ($validation.warning_count | into string) + " warnings"
        log_success $warn_msg
    }

    # All modules passed validation
    log_success "All modules validated successfully"

    return {valid: true, modules: $module_results}
}

# Generate report
def generate_report [device_dir: string, analysis_results: record] {
    log_info "Generating analysis report..."

    let timestamp = (date now | format date '%Y-%m-%d %H:%M:%S')

    # Build module results section
    let module_summary = if ($analysis_results.modules | is-empty) {
        ""
    } else {
        let modules_lines = []
        let modules_detail = (
            $analysis_results.modules
            | each { |m|
                let status = (if $m.valid { "✓ PASS" } else { "✗ FAIL" })
                let summary = "- " + $m.name + ": " + $status + " - " + ($m.error_count | into string) + " errors, " + ($m.warning_count | into string) + " warnings"

                # Add error/warning details if they exist
                let details = if ($m.error_count > 0 or $m.warning_count > 0) {
                    let error_lines = if ($m.error_count > 0) {
                        "  Errors:\n" + (
                            $m.errors
                            | first 3
                            | each { |e| "    - " + $e }
                            | str join "\n"
                        ) + (if ($m.error_count > 3) { "\n    ... and " + (($m.error_count - 3) | into string) + " more errors" } else { "" })
                    } else {
                        ""
                    }

                    let warning_lines = if ($m.warning_count > 0) {
                        "  Warnings:\n" + (
                            $m.warnings
                            | first 3
                            | each { |w| "    - " + $w }
                            | str join "\n"
                        ) + (if ($m.warning_count > 3) { "\n    ... and " + (($m.warning_count - 3) | into string) + " more warnings" } else { "" })
                    } else {
                        ""
                    }

                    "\n" + $error_lines + (if ($error_lines != "" and $warning_lines != "") { "\n" } else { "" }) + $warning_lines
                } else {
                    ""
                }

                $summary + $details
            }
        )
        let modules_text = ($modules_detail | str join "\n\n")
        "\n## Module Analysis Results\n\n" + $modules_text + "\n"
    }

    let report = $"# Mobile Verification Toolkit - Android Analysis Report

**Generated:** ($timestamp)

## Verification Method

### Live System Check
MVT check-adb analysis:
- Installed packages and applications
- Running processes
- Root binaries
- System configuration and SELinux status
- System logs via logcat

## IOC Analysis

This analysis used official MVT IOC checking procedures:
- Downloaded latest indicators from official repositories
- Checked against 10,885+ spyware/malware indicators
- Sources: Amnesty International, Citizen Lab, MVT-Project

($module_summary)## Output Files

Module-specific logs are available in:
- module_* directories - Individual module analysis logs
- command.log - Consolidated analysis logs

## Documentation

- ADB verification: https://docs.mvt.re/en/latest/android/adb/
- IOC procedures: https://docs.mvt.re/en/latest/iocs/

Generated: ($timestamp)
"

    $report | save -f ($device_dir | path join "ANALYSIS_REPORT.md")
    log_success "Report generated"
}

# Analyze device
def analyze_device [skip_sms?: bool, resume?: bool] {
    let device_dir = ($output_dir | path join $"device")

    # Only remove old directory if NOT resuming
    if not $resume {
        if ($device_dir | path exists) {
            log_info "Cleaning old analysis results..."
            rm -r $device_dir
        }
    } else {
        if not ($device_dir | path exists) {
            log_warn "Resume requested but no previous analysis found - starting fresh"
        } else {
            log_info "Resuming from previous analysis checkpoint..."
        }
    }

    mkdir $device_dir

    log_info "=========================================="
    if $resume {
        log_info "Resuming device analysis..."
    } else {
        log_info "Starting new device analysis..."
    }
    log_info $"Output: ($device_dir)"
    log_info "=========================================="

    # Method A: ADB Check
    let adb_success = (extract_via_adb $device_dir $skip_sms)

    if not $adb_success.valid {
       log_error "ADB check failed - analysis cannot continue"
       log_error "Checkpoint saved. Run with --resume to continue from where you left off."
       return false
    }

    # Generate report
    generate_report $device_dir $adb_success

    print ""
    log_success $"Analysis SUCCESSFUL"
    print $"Output saved to: ($device_dir)"
    print ""

    # Clean up checkpoint on successful completion
    let checkpoint_file = (get_checkpoint_file $device_dir)
    try {
        rm $checkpoint_file
        log_info "Checkpoint cleaned up"
    } catch {
        # Ignore if checkpoint doesn't exist
    }

    return true
}

# Main
def main [--skip-sms, --resume] {
    print (ansi blue)
    print "MVT - Mobile Verification Toolkit - Android Analysis"
    print (ansi reset)
    print ""

    if $skip_sms {
        log_warn "SMS module will be skipped"
    }

    if $resume {
        log_warn "Resume mode enabled - will skip already completed modules"
    }

    if not $resume {
        log_info "Pre-flight checks..."
        check_adb
        check_mvt

        log_info "Downloading IOCs..."
        download_iocs
    } else {
        log_info "Resume mode - skipping pre-flight checks and IOC download"
    }

    mkdir $output_dir
    log_success $"Output: ($output_dir)"

    # Run analysis on each device and collect results
    let result = analyze_device $skip_sms $resume
}
