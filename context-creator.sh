#!/bin/bash

# ==============================================================================
# CONTEXT DIRECTORY CREATOR SCRIPT
# ==============================================================================
#
# PURPOSE:
# This script creates a flattened directory structure called "context" where
# all files from specified folders are copied with renamed filenames that
# preserve their original path information.
#
# HOW IT WORKS:
# 1. Takes a predefined list of folders from the current directory
# 2. Recursively finds all files within those folders
# 3. Creates a "context" directory (removes existing one if present)
# 4. Copies all files to the context directory with special naming:
#    Original: src/components/Button.jsx
#    Becomes:  Button-_-src-components.jsx
#    Format:   <filename>-_-<path-with-dashes>.<extension>
#
# LLM PROMPT FOR CONTEXT:
# Context files were generated from a script that flattens the project's directories and files into a single context directory. The files are renamed to include their original path information, making it easier to understand their context within the project structure. The format is as follows : <filename>-_-<path-with-dashes>.<extension>. The path is relative from the repo's root.
# USAGE:
# ./create_context.sh                    # Creates context/ with timestamped name
# ./create_context.sh -d my_context      # Creates my_context/ directory
# ./create_context.sh -h                 # Show help
#
# EXAMPLE OUTPUT STRUCTURE:
# context/
# ├── README-_-root.md
# ├── index-_-src.js
# ├── Button-_-src-components.jsx
# ├── api-_-src-utils.js
# ├── main-_-docs-getting-started.md
# └── config-_-config-database.json
#
# FILE SKIPPING:
# The script can skip files matching specified patterns (e.g., secrets, vault files)
# Edit the SKIP_PATTERNS array to control which files are excluded
#
# ==============================================================================

# ====== CONFIGURATION SECTION ======
# Edit this list to specify which folders to process
FOLDERS=(
    "playbooks"
    "terraform"
)

# Patterns of files to skip (uses grep -E pattern matching)
SKIP_PATTERNS=(
    ".terraform/"
    ".terraform"
    ".terraform\\"
    "terraform.tfstate\\"
    "vault\\."
    "secrets\\.env"
    "secrets-production.yaml"
    "secrets-production.yml"
    "secrets.yaml"
    "secrets.yml"
)

# Default context directory name
CONTEXT_DIR="context/context_$(date +%Y%m%d_%H%M%S)"
# ===================================

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            CONTEXT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            echo "Context Directory Creator"
            echo "Usage: $0 [-d context_dir_name]"
            echo "  -d, --dir       Specify context directory name"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "This script flattens files from specified folders into a single directory"
            echo "with renamed files that preserve original path information."
            echo ""
            echo "Folders to be processed (edit script to modify):"
            for folder in "${FOLDERS[@]}"; do
                echo "  - $folder"
            done
            echo ""
            echo "Files matching these patterns will be skipped:"
            if [ ${#SKIP_PATTERNS[@]} -eq 0 ]; then
                echo "  (No skip patterns defined)"
            else
                for pattern in "${SKIP_PATTERNS[@]}"; do
                    echo "  - $pattern"
                done
            fi
            echo ""
            echo "File naming format: <filename>-_-<path-with-dashes>.<extension>"
            echo "Example: src/utils/helper.js becomes helper-_-src-utils.js"
            echo ""
            exit 0
            ;;
        -*)
            echo "Unknown option: $1"
            exit 1
            ;;
        *)
            echo "Error: Unexpected argument: $1"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

echo "Context Directory Creator"
echo "========================"

# Validate that all specified folders exist
missing_folders=()
valid_folders=()

echo "Checking folders..."
for folder in "${FOLDERS[@]}"; do
    if [ -d "$folder" ]; then
        valid_folders+=("$folder")
        echo "✓ Found folder: $folder"
    else
        missing_folders+=("$folder")
        echo "✗ Missing folder: $folder"
    fi
done

# Continue even if some folders are missing (just warn)
if [ ${#missing_folders[@]} -gt 0 ]; then
    echo ""
    echo "Warning: The following folders do not exist and will be skipped:"
    for folder in "${missing_folders[@]}"; do
        echo "  - $folder"
    done
fi

# Exit if no valid folders found
if [ ${#valid_folders[@]} -eq 0 ]; then
    echo ""
    echo "Error: No valid folders found to process"
    exit 1
fi

# Remove existing context directory if it exists
if [ -d "$CONTEXT_DIR" ]; then
    echo ""
    echo "Warning: $CONTEXT_DIR already exists. Removing..."
    rm -rf "$CONTEXT_DIR"
fi

# Create the context directory
mkdir -p "$CONTEXT_DIR"
echo ""
echo "Created directory: $CONTEXT_DIR"

# Function to convert path to filename format
convert_path_to_filename() {
    local filepath="$1"
    local dir_path=$(dirname "$filepath")
    local filename=$(basename "$filepath")
    local name_without_ext="${filename%.*}"
    local extension="${filename##*.}"

    # Convert directory path: replace / with - and remove leading ./
    local path_part=$(echo "$dir_path" | sed 's|^\./||' | sed 's|/|-|g')

    # Handle root directory case
    if [ "$path_part" = "." ]; then
        path_part="root"
    fi

    # Construct new filename
    if [ "$filename" = "$name_without_ext" ]; then
        # No extension
        echo "${name_without_ext}-_-${path_part}"
    else
        # Has extension
        echo "${name_without_ext}-_-${path_part}.${extension}"
    fi
}

# Function to check if file should be skipped
should_skip_file() {
    local filepath="$1"

    for pattern in "${SKIP_PATTERNS[@]}"; do
        if echo "$filepath" | grep -E "$pattern" >/dev/null; then
            return 0  # Should skip (true)
        fi
    done

    return 1  # Should not skip (false)
}

# Process each valid folder
total_files=0
skipped_files=0
echo ""
echo "Processing files..."

for folder in "${valid_folders[@]}"; do
    echo ""
    echo "Processing folder: $folder"

    # Find all files recursively in the folder
    while IFS= read -r -d '' file; do
        # Skip if it's a directory
        if [ -f "$file" ]; then
            # Check if file should be skipped based on patterns
            if should_skip_file "$file"; then
                echo "  ⨯ Skipping $file (matches skip pattern)"
                ((skipped_files++))
                continue
            fi

            # Convert path to new filename
            new_filename=$(convert_path_to_filename "$file")

            # Copy file to context directory with new name
            cp "$file" "$CONTEXT_DIR/$new_filename"

            echo "  ✓ $file → $new_filename"
            ((total_files++))
        fi
    done < <(find "$folder" -type f -print0 2>/dev/null)
done

echo ""
echo "===================="
echo "✓ Successfully processed $total_files files"
if [ $skipped_files -gt 0 ]; then
    echo "⨯ Skipped $skipped_files files matching patterns"
fi
echo "✓ Created context directory: $CONTEXT_DIR"

# Show directory contents summary
echo ""
echo "Context directory contents:"
ls -la "$CONTEXT_DIR" | head -10
if [ $(ls -1 "$CONTEXT_DIR" | wc -l) -gt 10 ]; then
    echo "... (showing first 10 files)"
fi

echo ""
echo "Total files in context: $(ls -1 "$CONTEXT_DIR" | wc -l)"

# Show directory size if du command is available
if command -v du &> /dev/null; then
    echo "Directory size: $(du -sh "$CONTEXT_DIR" | cut -f1)"
fi