#!/bin/bash
#
# DHI JAR Vulnerability Patching Script v1.0
# Automated JAR replacement system for DHI images

set -eo pipefail

#==============================================================================
# CONSTANTS AND GLOBAL VARIABLES
#==============================================================================

# Script metadata
readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0"

# Default configuration
readonly DEFAULT_CONFIG="dhi-patch-config.json"
readonly DEFAULT_MAVEN_BASE="https://repo1.maven.org/maven2"

# Command line arguments (initialized as empty, set by parse_arguments)
APP_ROOT=""
PATCH_DIR=""
CONFIG_FILE=""
CREATE_BACKUPS="false"

# Runtime variables (set during execution)
TEMP_DIR="/tmp/dhi-patching-$$"
APP_NAME=""
APP_VERSION=""
MAVEN_BASE=""

# Counters for reporting
strategy_count=0
patch_count=0
success_count=0
patch_success=0

#==============================================================================
# UTILITY FUNCTIONS
#==============================================================================

# Display usage information and exit
usage() {
    cat << EOF
${SCRIPT_NAME} v${VERSION} - DHI JAR Vulnerability Patching

Usage: $0 --app-root <path> [--patch-dir <path>] [--config <file>]

Required Arguments:
  --app-root             Path to application distribution root

Optional Arguments:
  --patch-dir            Path to directory containing patch dependencies
  --config               DHI patch configuration file (default: ${DEFAULT_CONFIG})
  --create-backups       Create backup files before patching (useful for runtime patching)
  -h, --help            Show this help message

Description:
  This DHI JAR vulnerability patching script:
  1. Reads JAR patch configuration from JSON
  2. Validates required patch JARs are pre-staged in build
  3. Applies JAR replacement patches for known CVEs
  4. Creates backups and verifies patch integrity

Examples:
  $0 --app-root /opt/myapp
  $0 --app-root /opt/myapp --patch-dir /tmp/patches
  $0 --app-root /opt/myapp --config custom-patch-config.json
  $0 --app-root /opt/myapp --create-backups  # Runtime patching with rollback capability
EOF
    exit 1
}

# Log messages with consistent formatting
log_info() {
    echo "ℹ️  $*"
}

log_success() {
    echo "✅ $*"
}

log_warning() {
    echo "⚠️  $*" >&2
}

log_error() {
    echo "❌ $*" >&2
}

# Get file size in a secure, cross-platform way
get_file_size() {
    local file="$1"
    if [[ -f "$file" ]]; then
        stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

#==============================================================================
# VALIDATION FUNCTIONS
#==============================================================================

# Validate that patch config versions match downloaded JAR versions
validate_patch_download_consistency() {
    echo "🗒 Validating patch/download version consistency..." >&2
    echo "    📂 Patch directory: $PATCH_DIR" >&2
    echo "    📄 Config file: $CONFIG_FILE" >&2

    local validation_errors=0
    local patch_number=0

    while IFS= read -r patch; do
        if [[ "$patch" == "{}" || -z "$patch" ]]; then
            continue
        fi

        patch_number=$((patch_number + 1))

        local group_id
        local artifact_id
        local expected_version

        group_id=$(echo "$patch" | jq -r '.groupId')
        artifact_id=$(echo "$patch" | jq -r '.artifactId')
        expected_version=$(echo "$patch" | jq -r '.version')

        if [[ -n "$group_id" && -n "$artifact_id" && -n "$expected_version" ]]; then
            local expected_jar="$PATCH_DIR/$artifact_id-$expected_version.jar"

            if [[ -f "$expected_jar" ]]; then
                log_success "  ✓ $artifact_id: Config($expected_version) = Downloaded($expected_version)" >&2
            else
                log_error "  ❌ $artifact_id: MISMATCH DETECTED!" >&2
                echo "    📝 Expected JAR: $expected_jar" >&2
                echo "    💺 Available JARs in patch dir:" >&2
                find "$PATCH_DIR" -name "$artifact_id-*.jar" -exec basename {} \; 2>/dev/null | sed 's/^/      /' >&2 || echo "      (none found)" >&2
                echo "    ⚠️  This indicates a version mismatch between:" >&2
                echo "      - Patch config JSON (expects: $expected_version)" >&2
                echo "      - File downloaded in DHI YAML definition is different version than in config!" >&2
                echo "    🚫 SECURITY RISK: Vulnerabilities may remain unpatched!" >&2
                validation_errors=$((validation_errors + 1))
            fi
        fi
    done < <(jq -c '.patches[]' "$CONFIG_FILE" 2>/dev/null || echo '{}')

    if [[ $validation_errors -gt 0 ]]; then
        echo >&2
        log_error "🚨 CRITICAL: $validation_errors patch/download version mismatches detected!" >&2
        echo "" >&2
        echo "    🚫 BUILD MUST FAIL to prevent security vulnerabilities!" >&2
        echo "" >&2
        echo "    🛠️  TO FIX:" >&2
        echo "    1. Update files section of image build definition. Patch file downloaded into build step does not match patch config versions" >&2
        echo "    2. OR update patch config versions to match downloaded JARs" >&2
        echo "    3. Ensure both files reference the same version for each library" >&2
        echo "" >&2
        echo "    📁 Files to check:" >&2
        echo "      - Patch config: $(basename "$CONFIG_FILE")" >&2
        echo "      - DHI build YAML: debian/.sonarqube.inc.yaml" >&2
        echo >&2
        return 1
    else
        log_success "  ✓ All patch versions match downloaded JARs" >&2
        echo >&2
        return 0
    fi
}

# Validate search patterns to prevent injection attacks
validate_pattern() {
    local pattern="$1"

    # Check for dangerous characters that could lead to command injection
    # Allow shell wildcards but block command injection characters
    if [[ "$pattern" =~ [\;\&\|\`\$\(\)\<\>] ]]; then
        log_error "Unsafe search pattern detected (contains command injection characters): $pattern"
        return 1
    fi

    # Block patterns that could traverse directories
    if [[ "$pattern" =~ \.\./|\.\.\\ ]]; then
        log_error "Unsafe search pattern detected (contains directory traversal): $pattern"
        return 1
    fi

    return 0
}

# Validate JSON configuration files
validate_json_config() {
    local config_file="$1"

    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    # Test if JSON is valid
    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid JSON in configuration file: $config_file"
        return 1
    fi

    return 0
}

# Validate command line arguments
validate_arguments() {
    if [[ -z "$APP_ROOT" ]]; then
        log_error "Missing required --app-root argument"
        usage
    fi

    if [[ ! -d "$APP_ROOT" ]]; then
        log_error "Application root directory not found: $APP_ROOT"
        exit 1
    fi

    # Set default config file if not provided
    if [[ -z "$CONFIG_FILE" ]]; then
        CONFIG_FILE="$SCRIPT_DIR/$DEFAULT_CONFIG"
    fi

    # Validate configuration file
    if ! validate_json_config "$CONFIG_FILE"; then
        exit 1
    fi
}

#==============================================================================
# PATCH OPERATION FUNCTIONS
#==============================================================================

# Validate that required patch JAR is available (pre-staged)
validate_patch_jar() {
    local group_id="$1"
    local artifact_id="$2"
    local version="$3"
    local jar_name="$artifact_id-$version.jar"
    local jar_path="$PATCH_DIR/$jar_name"

    if [[ -f "$jar_path" ]]; then
        log_success "Found pre-staged patch: $jar_name"
        echo "    📍 Path: $jar_path"
        echo "    📏 Size: $(get_file_size "$jar_path") bytes"
        return 0
    else
        log_error "Pre-staged patch JAR not found: $jar_name"
        echo "    📍 Expected path: $jar_path"
        echo "    💺 Available JARs in patch directory:"
        find "$PATCH_DIR" -name "$artifact_id-*.jar" -exec basename {} \; 2>/dev/null | sed 's/^/      /' || echo "      (none found for $artifact_id)"
        echo "    ⚠️  This suggests a version mismatch between:"
        echo "      - dhi-patch-config.json (expects: $version)"
        echo "      - DHI YAML download URLs (downloaded different version)"
        echo "    🔍 Check both files ensure versions match exactly"
        return 1
    fi
}

# Replace vulnerable JARs with security patches
replace_vulnerable_jar() {
    local vulnerable_path="$1"
    local patch_jar="$2"
    local cve="$3"

    # Validate input files exist
    if [[ ! -f "$vulnerable_path" ]]; then
        log_warning "Vulnerable JAR not found: $vulnerable_path"
        return 1
    fi

    if [[ ! -f "$patch_jar" ]]; then
        log_error "Patch JAR not found: $patch_jar"
        echo "    📍 Expected path: $patch_jar"
        return 1
    fi

    # Format CVE information for display
    local cve_display="general security updates"
    if [[ -n "$cve" && "$cve" != "null" ]]; then
        cve_display="$cve"
    fi

    echo "    🔄 Replacing $(basename "$vulnerable_path") for $cve_display"
    echo "    📊 Original size: $(get_file_size "$vulnerable_path") bytes"
    echo "    📊 Patch size: $(get_file_size "$patch_jar") bytes"

    # Create backup before replacement (only if --create-backups specified)
    if [[ "$CREATE_BACKUPS" == "true" ]]; then
        if ! cp "$vulnerable_path" "${vulnerable_path}.backup"; then
            log_error "Failed to create backup of $vulnerable_path"
            return 1
        fi
    fi

    # Replace with patch and verify
    local target_dir=$(dirname "$vulnerable_path")
    local old_filename=$(basename "$vulnerable_path")
    local patch_filename=$(basename "$patch_jar")
    local final_path="$vulnerable_path"

    # Check if we need to rename the file (different version in filename)
    if [[ "$old_filename" != "$patch_filename" ]]; then
        local new_path="$target_dir/$patch_filename"
        echo "    📝 File will be renamed: $old_filename → $patch_filename"

        # Copy patch to new filename location
        if cp "$patch_jar" "$new_path"; then
            # Set proper permissions for non-root user access
            chmod 644 "$new_path"
            # Remove the old file
            rm "$vulnerable_path"
            final_path="$new_path"
            echo "    🗑️  Removed old file: $old_filename"
        else
            log_error "Failed to copy patch JAR to new location: $new_path"
            return 1
        fi
    else
        # Same filename, just overwrite content
        if ! cp "$patch_jar" "$vulnerable_path"; then
            log_error "Failed to copy patch JAR"
            return 1
        fi
        # Set proper permissions for non-root user access
        chmod 644 "$vulnerable_path"
    fi

    # Verify the replacement worked
    local new_size=$(get_file_size "$final_path")
    local patch_size=$(get_file_size "$patch_jar")

    if [[ "$new_size" == "$patch_size" ]]; then
        log_success "Successfully patched: $(basename "$final_path")"
        echo "    🔍 Verified: New size matches patch ($new_size bytes)"
        return 0
    else
        log_warning "Size mismatch after replacement! New: $new_size, Expected: $patch_size"
        if [[ "$CREATE_BACKUPS" == "true" && -f "${vulnerable_path}.backup" ]]; then
            echo "    🔄 Restoring backup..."
            cp "${vulnerable_path}.backup" "$vulnerable_path"
        else
            log_error "Cannot restore - no backup available (backup creation disabled)"
        fi
        return 1
    fi
}

#==============================================================================
# CONFIGURATION AND SETUP FUNCTIONS
#==============================================================================

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --app-root)
                APP_ROOT="$2"
                shift 2
                ;;
            --patch-dir)
                PATCH_DIR="$2"
                shift 2
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --create-backups)
                CREATE_BACKUPS="true"
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown argument: $1"
                usage
                ;;
        esac
    done
}

# Initialize runtime environment
setup_environment() {
    # Validate arguments first
    validate_arguments

    # Create temporary workspace
    mkdir -p "$TEMP_DIR/downloads"
    if [[ -z "$PATCH_DIR" ]]; then
        PATCH_DIR="$TEMP_DIR/downloads"
        log_info "Using temporary patch directory: $PATCH_DIR"
    else
        # Convert to absolute path to avoid issues when changing directories
        PATCH_DIR=$(realpath "$PATCH_DIR")
    fi

    # Set up cleanup trap
    trap "rm -rf '$TEMP_DIR'" EXIT

    # Load application configuration from JSON
    APP_NAME=$(jq -r '.application // "unknown"' "$CONFIG_FILE")
    APP_VERSION=$(jq -r '.version // "unknown"' "$CONFIG_FILE")
    MAVEN_BASE=$(jq -r ".maven_central_base // \"$DEFAULT_MAVEN_BASE\"" "$CONFIG_FILE")
}

# Display configuration information
show_banner() {
    echo "🎯 DHI JAR Vulnerability Patching v$VERSION"
    echo "=========================================="
    echo "   Application: $APP_NAME v$APP_VERSION"
    echo "   Target Root: $APP_ROOT"
    echo "   Patch Dir: $PATCH_DIR"
    echo "   Config: $(basename "$CONFIG_FILE")"
    echo
}

#==============================================================================
# CORE PATCH PROCESSING FUNCTIONS
#==============================================================================

# Validate all patch configurations
validate_patch_configs() {
    echo "🔧 PHASE 1: VALIDATING PATCH CONFIGURATIONS" >&2
    echo "============================================" >&2

    # Count total patches
    local patch_count
    patch_count=$(jq -r '.patches | length' "$CONFIG_FILE")

    if [[ $patch_count -eq 0 ]]; then
        log_error "No patches defined in configuration"
        return 1
    fi

    log_success "Found $patch_count JAR patches to validate" >&2
    echo >&2

    # Validate patch/download version consistency
    if ! validate_patch_download_consistency; then
        log_error "Patch/download version validation failed" >&2
        return 1
    fi

    return 0
}

# Validate all required patch JARs are available
validate_patch_jars() {
    echo "🔧 PHASE 2: VALIDATING PATCH JARS"
    echo "=================================="

    patch_count=0
    success_count=0

    while IFS= read -r patch; do
        if [[ "$patch" == "{}" || -z "$patch" ]]; then
            continue
        fi

        local group_id
        local artifact_id
        local version

        group_id=$(echo "$patch" | jq -r '.groupId')
        artifact_id=$(echo "$patch" | jq -r '.artifactId')
        version=$(echo "$patch" | jq -r '.version')

        if [[ -n "$group_id" && -n "$artifact_id" && -n "$version" ]]; then
            patch_count=$((patch_count + 1))
            echo "${patch_count}️⃣ $artifact_id $version:"
            if validate_patch_jar "$group_id" "$artifact_id" "$version"; then
                success_count=$((success_count + 1))
            fi
        fi
    done < <(jq -c '.patches[]' "$CONFIG_FILE" 2>/dev/null || echo '{}')

    echo
    echo "📋 Patch JARs Status: $success_count/$patch_count available"
    echo
}

# Apply all configured patches
apply_patches() {
    echo "🔧 PHASE 3: APPLYING PATCHES"
    echo "============================"

    patch_success=0

    echo "🎯 Applying JAR replacement patches from: $(basename "$CONFIG_FILE")"
    apply_jar_patches
}

# Apply JAR replacement patches from configuration file
apply_jar_patches() {
    while IFS= read -r patch; do
        if [[ "$patch" == "{}" || -z "$patch" ]]; then
            continue
        fi

        local group_id
        local artifact_id
        local version
        local cve_fixes
        local patch_jar
        local search_paths
        local replaces_patterns

        group_id=$(echo "$patch" | jq -r '.groupId')
        artifact_id=$(echo "$patch" | jq -r '.artifactId')
        version=$(echo "$patch" | jq -r '.version')
        cve_fixes=$(echo "$patch" | jq -r '.cve_fixes[]? // empty' | tr '\n' ',' | sed 's/,$//')

        echo "📦 Processing $artifact_id $version:"

        patch_jar="$PATCH_DIR/$artifact_id-$version.jar"
        search_paths=$(echo "$patch" | jq -r '.search_paths[]? // empty')
        replaces_patterns=$(echo "$patch" | jq -r '.replaces[]? // empty')

        # Search for vulnerable JARs in specified paths
        while IFS= read -r search_path; do
            if [[ -z "$search_path" ]]; then
                continue
            fi

            local full_search_path="$APP_ROOT/$search_path"
            if [[ -d "$full_search_path" ]]; then
                while IFS= read -r pattern; do
                    if [[ -z "$pattern" ]]; then
                        continue
                    fi

                    # Validate pattern for security
                    if ! validate_pattern "$pattern"; then
                        log_warning "Skipping unsafe pattern: $pattern"
                        continue
                    fi

                    local vulnerable_jars
                    vulnerable_jars=$(find "$full_search_path" -name "$pattern" -type f 2>/dev/null | grep -v backup || true)

                    if [[ -n "$vulnerable_jars" ]]; then
                        while IFS= read -r jar; do
                            if [[ -n "$jar" ]]; then
                                echo "  → Found: $jar"
                                if replace_vulnerable_jar "$jar" "$patch_jar" "$cve_fixes"; then
                                    patch_success=$((patch_success + 1))
                                fi
                            fi
                        done <<< "$vulnerable_jars"
                    fi
                done <<< "$replaces_patterns"
            fi
        done <<< "$search_paths"
    done < <(jq -c '.patches[]' "$CONFIG_FILE" 2>/dev/null || echo '{}')
}

# Display final patching results
show_summary() {
    echo
    echo "🏁 PATCHING SUMMARY"
    echo "=================="
    log_success "JAR-level patches applied: $patch_success"

    local backup_count
    backup_count=$(find "$APP_ROOT" -name "*.jar.backup" -type f 2>/dev/null | wc -l)
    echo "💾 Total backup files created: $backup_count"

    if [[ $patch_success -gt 0 ]]; then
        echo "🎉 DHI patching completed with $patch_success successful patches!"
    else
        log_info "No patches were applied (this may be normal if no vulnerable JARs were found)"
    fi

    echo
    echo "📋 Next steps:"
    echo "  • Run a vulnerability scan to verify fixes"
    echo "  • Check application functionality"
    echo "  • Review patch configuration for completeness"
}

#==============================================================================
# MAIN EXECUTION FUNCTION
#==============================================================================

# Main execution flow
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Initialize environment and validate configuration
    setup_environment

    # Display configuration banner
    show_banner

    # Validate patch configurations (includes version consistency check)
    if ! validate_patch_configs; then
        log_error "Patch configuration validation failed - aborting to prevent security issues"
        exit 1
    fi

    # Validate required patch JARs
    validate_patch_jars

    # Apply patches
    apply_patches

    # Show summary
    show_summary
}

#==============================================================================
# SCRIPT EXECUTION
#==============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
