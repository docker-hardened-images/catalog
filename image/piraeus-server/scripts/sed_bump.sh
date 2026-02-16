#!/bin/sh
set -e;

# Extract version from a line using a pattern
# The pattern should have a capture group for the version, or we'll try to extract a version-like pattern
extract_version_from_line() {
    line="$1"
    pattern="$2"

    # Try to extract using the pattern with a capture group
    # First, extract the matching portion using grep -oE
    match=$(echo "$line" | grep -oE "$pattern" | head -1)

    if [ -n "$match" ]; then
        # Try to extract each capture group and find the one that looks like a version
        # Count capture groups by counting unescaped opening parentheses
        # Extract all capture groups and find the version-like one
        # For patterns like (prefix)(version)(suffix), we want the middle one

        # Try extracting \1, \2, \3, etc. until we find a version-like string
        for i in 1 2 3 4 5; do
            extracted=$(echo "$match" | sed -nE "s|$pattern|\\$i|p" 2>/dev/null || echo "")
            if [ -n "$extracted" ]; then
                # Check if it looks like a version (contains digits and dots, or alphanumeric with dots)
                if echo "$extracted" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)*([.-][A-Za-z0-9]+)*$'; then
                    echo "$extracted"
                    return 0
                fi
            fi
        done

        # If no capture group looks like a version, try the first non-empty one
        for i in 1 2 3 4 5; do
            extracted=$(echo "$match" | sed -nE "s|$pattern|\\$i|p" 2>/dev/null || echo "")
            if [ -n "$extracted" ] && [ "$extracted" != "$match" ]; then
                echo "$extracted"
                return 0
            fi
        done
    fi

    # Fallback: try to find a version pattern (numbers and dots) in the matched line
    # This matches patterns like 1.2.3, 1.2.3.4, 4.1.129.Final, etc.
    extracted=$(echo "$line" | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*([.-][A-Za-z0-9]+)*' | head -1)

    if [ -n "$extracted" ]; then
        echo "$extracted"
        return 0
    fi

    echo ""
}

# Skip main code for bats unit tests
if [ -z "${DHI_BATS_TEST:-}" ]; then

if [ -z "$DHI_WITH_FILE" ]; then
    echo "ERROR: file not set"
    exit 1
fi

target_file=$(echo "$DHI_WITH_FILE" | tr -d '"')

if [ ! -f "$target_file" ]; then
    echo "ERROR: file $target_file does not exist"
    exit 1
fi

if [ -z "$DHI_WITH_BUMPS" ]; then
    echo "ERROR: bumps array not set"
    exit 1
fi

bumps_file=$(echo "$DHI_WITH_BUMPS" | tr -d '"')

if [ ! -f "$bumps_file" ]; then
    echo "ERROR: bumps file $bumps_file does not exist"
    exit 1
fi

echo "Processing bumps in $target_file"

# Process each bump in the JSON array
jq -c '.[]' "$bumps_file" | while read -r bump; do
    pattern=$(echo "$bump" | jq -r '.pattern')
    allow_downgrade=$(echo "$bump" | jq -r '.allow_downgrade // false')
    new_version=$(echo "$bump" | jq -r '.version')

    if [ -z "$pattern" ] || [ "$pattern" = "null" ]; then
        echo "ERROR: pattern is required for each bump"
        exit 1
    fi

    if [ -z "$new_version" ] || [ "$new_version" = "null" ]; then
        echo "ERROR: version is required for each bump"
        exit 1
    fi

    echo "Processing bump with pattern: $pattern, version: $new_version, allow_downgrade: $allow_downgrade"

    # Check if pattern has capture groups when downgrade protection is enabled
    if [ "$allow_downgrade" = "false" ]; then
        # Check if pattern contains unescaped parentheses (capture groups)
        # With extended regex, parentheses are capture groups unless escaped or followed by ?
        # Look for ( that's not \( and not (?
        if ! echo "$pattern" | grep -qE '(^|[^\\])\([^?]'; then
            echo "ERROR: Pattern must contain a capture group (parentheses) when allow_downgrade is false. Pattern: $pattern"
            exit 1
        fi
    fi

    # Find matching lines in the file and store in temp file to avoid subshell issues
    matches_file=$(mktemp)
    grep -nE "$pattern" "$target_file" > "$matches_file" 2>/dev/null || true

    if [ ! -s "$matches_file" ]; then
        echo "ERROR: No lines matched pattern $pattern in $target_file"
        rm -f "$matches_file"
        exit 1
    fi

    # Track if any replacements were made for this pattern
    replacements_made=0

    # Process each matching line
    while IFS=: read -r line_num line_content; do
        echo "Found match on line $line_num: $line_content"

        # Extract current version from the line
        current_version=$(extract_version_from_line "$line_content" "$pattern")

        if [ -z "$current_version" ]; then
            if [ "$allow_downgrade" = "false" ]; then
                echo "ERROR: Could not extract version from line $line_num using pattern $pattern. When allow_downgrade is false, the pattern must have a capture group to extract the version."
                rm -f "$matches_file"
                exit 1
            else
                echo "WARNING: Could not extract version from line $line_num, skipping downgrade check"
            fi
        else

            echo "Extracted current version: $current_version"

            # Check for downgrade if not allowed
            if [ "$allow_downgrade" = "false" ]; then
                older_version=$(printf "%s\n%s" "$current_version" "$new_version" | sort -V | head -1)
                echo "Comparing versions: current=$current_version, new=$new_version, older=$older_version"

                if [ -n "$current_version" ] && [ "$older_version" != "$current_version" ]; then
                    echo "ERROR: Failing bump - current value is $current_version and trying to downgrade to $new_version with allow_downgrade set to false"
                    rm -f "$matches_file"
                    exit 1
                fi
            fi
        fi

        # Use sed to replace the version in the pattern match
        # Simple approach: if we extracted a version, replace that version string with new_version
        temp_file=$(mktemp)

        if [ -n "$current_version" ]; then
            # Replace the current_version with new_version on this line
            # Escape special characters in current_version for sed
            escaped_current=$(echo "$current_version" | sed 's/[[\.*^$()+?{|]/\\&/g')
            sed -E "${line_num}s|$escaped_current|$new_version|g" "$target_file" > "$temp_file"
        else
            # If we couldn't extract version, try replacing the pattern match directly
            # This assumes the pattern matches what we want to replace
            # Use -E for extended regex to match grep -E behavior
            sed -E "${line_num}s|$pattern|$new_version|g" "$target_file" > "$temp_file"
        fi

        # Check if sed made any changes
        if ! diff -q "$target_file" "$temp_file" > /dev/null 2>&1; then
            mv "$temp_file" "$target_file"
            echo "Updated line $line_num"
            replacements_made=$((replacements_made + 1))
        else
            rm -f "$temp_file"
            echo "ERROR: sed replacement failed for line $line_num - no changes were made. Pattern may need adjustment."
            rm -f "$matches_file"
            exit 1
        fi
    done < "$matches_file"

    rm -f "$matches_file"

    # Ensure at least one replacement was made
    if [ "$replacements_made" -eq 0 ]; then
        echo "ERROR: No replacements were made for pattern $pattern in $target_file"
        exit 1
    fi
done

echo "Finished processing bumps."

fi
