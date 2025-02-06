#!/bin/bash

# Configuration
OLLAMA_MODEL="codellama"
REVIEW_FILE="review_results"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKING_DIR="$(pwd)"
DEBUG=true

# Debug logging function
debug_log() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1" >&2
        echo "[DEBUG] $1" >> "$WORKING_DIR/git-review-debug.log"
    fi
}

# Force immediate output flush
export PYTHONUNBUFFERED=1


# Function to check if Ollama is running
check_ollama() {
    debug_log "Checking Ollama connection..."
    local response
    response=$(curl -s http://localhost:11434/api/tags)
    if [ $? -ne 0 ]; then
        echo "Error: Ollama is not running. Please start Ollama first."
        exit 1
    fi
    debug_log "Ollama connection successful. Response: $response"
}

# Function to get list of changed files, excluding gitignored and lock files
get_changed_files() {
    cd "$WORKING_DIR" || exit 1
    debug_log "Getting changed files in: $WORKING_DIR"
    local files
    files=$(git diff --name-only --diff-filter=d | grep -v -E '(package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|poetry.lock)$')
    debug_log "Found files: $files"
    echo "$files" | while read -r file; do
        if [ -f "$file" ] && ! git check-ignore -q "$file"; then
            echo "$file"
        fi
    done
}

# Function to get diff for a specific file
get_file_diff() {
    local file="$1"
    cd "$WORKING_DIR" || exit 1
    debug_log "Getting diff for file: $file"
    local diff
    diff=$(git diff "$file")
    debug_log "Diff length: ${#diff} characters"
    echo "$diff"
}

# Function to query Ollama for review
query_ollama() {
    local diff="$1"
    # local prompt="Review this git diff and provide a concise analysis of the changes. If there are no significant changes or concerns, respond with 'N/A'. Here's the diff:\n\n$diff"
    local prompt="You are a code reviewer analyzing a git diff. Your task is to review the changes and:

1. If there are significant changes or potential issues (security, performance, or best practices), provide a CONCISE bullet-point list of your findings
2. If there are no significant changes or concerns, respond ONLY with 'N/A' (no other text)

Here's the diff to review:\n\n$diff"
    
    debug_log "Querying Ollama with diff of length: ${#diff}"
    
    # Create a temporary file for the JSON payload
    local temp_file
    temp_file=$(mktemp)
    
    # Create properly escaped JSON
    cat > "$temp_file" << EOF
{
    "model": "${OLLAMA_MODEL}",
    "prompt": $(echo "$prompt" | jq -R -s .),
    "stream": false
}
EOF
    
    debug_log "Request payload:"
    debug_log "$(cat "$temp_file")"
    
    # Make the API call and capture full response
    local response
    response=$(curl -s -X POST http://localhost:11434/api/generate \
        -H "Content-Type: application/json" \
        -d @"$temp_file")
    
    debug_log "Raw API response:"
    debug_log "$response"
    
    # Clean up temp file
    rm "$temp_file"
    
    # Extract and validate the response
    if [ -z "$response" ]; then
        echo "Error: Empty response from Ollama"
        return 1
    fi
    
    local ai_response
    ai_response=$(echo "$response" | jq -r '.response // empty')
    
    if [ -z "$ai_response" ]; then
        debug_log "Error in API response:"
        debug_log "$(echo "$response" | jq -r '.error // "No error message provided"')"
        echo "Error: Invalid response from Ollama"
        return 1
    fi
    
    echo "$ai_response"
}

# Main execution
main() {
    # Store original directory
    local original_dir="$PWD"
    debug_log "Starting script in directory: $original_dir"

    # Check if we're in a git repository
    cd "$WORKING_DIR" || exit 1
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: $WORKING_DIR is not a git repository"
        cd "$original_dir" || exit 1
        exit 1
    fi

    # Check if required commands are available
    for cmd in curl jq git; do
        if ! command -v "$cmd" >/dev/null; then
            echo "Error: Required command '$cmd' is not installed"
            exit 1
        fi
    done

    # Check if Ollama is running
    check_ollama

    # Clear previous review results
    debug_log "Creating/clearing review file: $WORKING_DIR/$REVIEW_FILE"
    > "$WORKING_DIR/$REVIEW_FILE"

    # Process each changed file
    local process_count=0
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            ((process_count++))
            echo "Reviewing ($process_count): $file"
            
            # Get diff for the file
            local diff
            diff=$(get_file_diff "$file")
            
            if [ -n "$diff" ]; then
                debug_log "Processing diff for $file (${#diff} chars)"
                
                # Get AI review
                local review
                review=$(query_ollama "$diff")
                local query_status=$?
                
                if [ $query_status -eq 0 ] && [ -n "$review" ]; then
                    debug_log "Successfully got review for $file"
                    # Write to results file
                    {
                        echo "=== $file ==="
                        echo "$review"
                        echo -e "\n"
                    } >> "$WORKING_DIR/$REVIEW_FILE"
                else
                    debug_log "Failed to get review for $file (status: $query_status)"
                    {
                        echo "=== $file ==="
                        echo "Error: Failed to get review"
                        echo -e "\n"
                    } >> "$WORKING_DIR/$REVIEW_FILE"
                fi
            else
                debug_log "No diff found for $file"
            fi
        fi
    done < <(get_changed_files)

    if [ $process_count -eq 0 ]; then
        echo "No files to review"
    else
        echo "Review complete. Results saved in $WORKING_DIR/$REVIEW_FILE"
        debug_log "Processed $process_count files"
    fi
    
    # Return to original directory
    cd "$original_dir" || exit 1
}

# Run the script
echo "Starting git-review script..."
echo "Working directory: $WORKING_DIR"
echo "Debug mode: $DEBUG"
main
