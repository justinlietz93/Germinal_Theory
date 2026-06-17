#!/bin/bash
# =============================================================================
# build_repo.sh
# Creates a repository structure from a .germ blueprint file.
# =============================================================================

build_repo() {
    if [[ "$1" == "--help" || -z "$1" ]]; then
        echo "Usage: build_repo <blueprint.germ> [target_dir]"
        echo "Purpose: Creates a repo from a .germ blueprint file."
        echo
        echo "Format:"
        echo "  # Folders"
        echo "  folder1/"
        echo "  folder2/"
        echo "  # File: path/to/file.md"
        echo "  ---"
        echo "  content line 1"
        echo "  content line 2"
        echo "  ..."
        echo
        echo "If target_dir is omitted, uses the current directory."
        return 0
    fi

    local blueprint="$1"
    local target_dir="${2:-.}"  # default to current directory

    # --- 1. Check file extension and existence ---
    if [[ ! -f "$blueprint" ]]; then
        echo "❌ Error: File '$blueprint' not found." >&2
        return 1
    fi

    if [[ "$blueprint" != *.germ ]]; then
        echo "❌ Error: Expected a .germ file, got '$blueprint'." >&2
        return 1
    fi

    # --- 2. Validate the blueprint structure ---
    local has_folders=false
    local has_files=false
    local in_file_section=false
    local errors=()
    local line_num=0

    while IFS= read -r line || [ -n "$line" ]; do
        ((line_num++))
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Detect section headers
        if [[ "$line" == "# Folders" ]]; then
            has_folders=true
            continue
        elif [[ "$line" =~ ^#\ File:\ (.*)$ ]]; then
            has_files=true
            in_file_section=true
            local filepath="${BASH_REMATCH[1]}"
            # Check if filepath is valid (no leading slash, etc.)
            if [[ "$filepath" == /* ]]; then
                errors+=("Line $line_num: File path '$filepath' starts with '/', should be relative.")
            fi
            continue
        fi

        # Folder lines (only if not inside a file section)
        if [[ "$in_file_section" == false && "$line" =~ ^[^#].+/$ ]]; then
            continue
        fi

    done < "$blueprint"

    # After scanning, check required sections
    if [[ "$has_folders" == false ]]; then
        errors+=("Missing '# Folders' section.")
    fi
    if [[ "$has_files" == false ]]; then
        errors+=("Missing at least one '# File:' entry.")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        echo "❌ Blueprint validation failed:" >&2
        for err in "${errors[@]}"; do
            echo "   - $err" >&2
        done
        return 1
    fi

    echo "✅ Blueprint structure looks valid."

    # --- 3. Extract the repository ---
    mkdir -p "$target_dir"

    local current_file=""
    local current_content=""

    while IFS= read -r line || [ -n "$line" ]; do
        # Skip empty lines
        [[ -z "$line" ]] && continue

        # Folder section header - ignore
        if [[ "$line" == "# Folders" ]]; then
            continue
        fi

        # File header
        if [[ "$line" =~ ^#\ File:\ (.*)$ ]]; then
            # Save previous file if exists
            if [[ -n "$current_file" ]]; then
                mkdir -p "$target_dir/$(dirname "$current_file")"
                echo "$current_content" > "$target_dir/$current_file"
            fi
            current_file="${BASH_REMATCH[1]}"
            current_content=""
            continue
        fi

        # Inside a file section
        if [[ -n "$current_file" ]]; then
            # Skip the delimiter
            if [[ "$line" == "---" ]]; then
                continue
            fi
            # Append content
            if [[ -n "$current_content" ]]; then
                current_content+=$'\n'
            fi
            current_content+="$line"
            continue
        fi

        # Folder lines
        if [[ "$line" =~ ^[^#].+/$ ]]; then
            mkdir -p "$target_dir/${line%/}"
        fi

    done < "$blueprint"

    # Save the last file
    if [[ -n "$current_file" ]]; then
        mkdir -p "$target_dir/$(dirname "$current_file")"
        echo "$current_content" > "$target_dir/$current_file"
    fi

    echo "✅ Repository built in '$target_dir'."
}

# =============================================================================
# Main execution
# =============================================================================

build_repo "$@"