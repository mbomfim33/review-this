#!/bin/bash

# Configuration
OLLAMA_MODEL="codellama"
REVIEW_FILE="review_results.json"
DEBUG=false

# Parse command line arguments
parse_args() {
    COMPARE_MODE="current"  # Default to current changes
    COMPARE_BRANCH="develop"  # Default branch to compare against
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --mode|-m)
                COMPARE_MODE="$2"
                shift 2
                ;;
            --branch|-b)
                COMPARE_BRANCH="$2"
                shift 2
                ;;
            --debug|-d)
                DEBUG=true
                shift 1
                ;;
            --help|-h)
                echo "Usage: git-review [options]"
                echo "Options:"
                echo "  --mode, -m    Compare mode: 'current' (unstaged changes) or 'branch' (compare with branch)"
                echo "  --branch, -b  Branch to compare against (default: develop)"
                echo "  --debug, -d   Enable debug output"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

# Debug logging function with timestamp and component
debug_log() {
    if [ "$DEBUG" = true ]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        local component="${2:-MAIN}"  # Default component is MAIN if not specified
        local message="[$timestamp][$component] $1"
        echo "$message" >&2
        echo "$message" >> "$WORKING_DIR/git-review-debug.log"
    fi
}

# Function to check if Ollama is running
check_ollama() {
    if ! curl -s http://localhost:11434/api/tags >/dev/null; then
        echo "Error: Ollama is not running. Please start Ollama first."
        exit 1
    fi
}

# Function to get list of changed files based on comparison mode
get_changed_files() {
    cd "$WORKING_DIR" || exit 1
    debug_log "Getting changed files in: $WORKING_DIR (mode: $COMPARE_MODE)"
    
    if [ "$COMPARE_MODE" = "current" ]; then
        # Add all new files to git's index (without staging them)
        git add -N .
        
        # Use git status --porcelain to get both modified and untracked files
        git status --porcelain | grep -E '^[?M ][ M] ' | sed 's/^...//'
    else
        # Compare with specified branch
        git diff --name-only "$COMPARE_BRANCH"...HEAD
    fi | grep -v -E '(package-lock.json|yarn.lock|pnpm-lock.yaml|Gemfile.lock|poetry.lock)$' | \
        while read -r file; do
            if [ -f "$file" ] && ! git check-ignore -q "$file"; then
                debug_log "Found file to review: $file"
                echo "$file"
            fi
        done
}

# Function to get diff for a specific file
get_file_diff() {
    local file="$1"
    cd "$WORKING_DIR" || exit 1
    debug_log "Getting diff for file: $file"
    
    if [ "$COMPARE_MODE" = "current" ]; then
        if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            git diff "$file"
        else
            # File is untracked, show entire file as new
            echo "diff --git a/$file b/$file"
            echo "new file mode 100644"
            echo "--- /dev/null"
            echo "+++ b/$file"
            echo "@@ -0,0 +1,$(wc -l < "$file") @@"
            sed 's/^/+/' "$file"
        fi
    else
        git diff "$COMPARE_BRANCH"...HEAD -- "$file"
    fi
}

# Function to determine issue severity
determine_severity() {
    local response="$1"
    if echo "$response" | grep -qi "security\|vulnerability\|exploit"; then
        echo "high"
    elif echo "$response" | grep -qi "performance\|memory leak\|complexity"; then
        echo "medium"
    else
        echo "low"
    fi
}

# Function to query Ollama for review
query_ollama() {
    local diff="$1"
    local prompt="You are a code reviewer analyzing a git diff. You must follow these response rules exactly:

RESPONSE FORMAT:
1. If there are ANY issues (security, performance, best practices, or code quality): 
   - Respond with ONLY a bullet point list
   - Each bullet point should state the issue and its rationale
   - No introduction or conclusion text

2. If there are NO issues:
   - Respond with ONLY the exact text: N/A
   - No other text or explanation

Example good responses:
- For issues:
• useState dependency missing in useEffect - could cause stale closures
• Array index used as key - may cause rendering issues
• Inline styles reduce performance - should use CSS classes

- For no issues:
N/A

Here's the diff to review:\n\n$diff"
    
    debug_log "Querying Ollama for review"
    
    response=$(curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"$OLLAMA_MODEL\",
        \"prompt\": $(echo "$prompt" | jq -R -s .),
        \"stream\": false
    }" | jq -r '.response' || echo "Error querying Ollama")
    
    echo "$response"
}

# Function to generate markdown report
generate_markdown() {
    local json_file="$1"
    local markdown_file="${json_file%.json}.md"
    
    local prompt="Convert this JSON code review report into a well-formatted markdown document. 
    Group issues by severity (high, medium, low). 
    Include file names as headers. 
    Format code-related terms with backticks.
    Here's the JSON:\n\n$(cat "$json_file")"
    
    debug_log "Generating markdown report"
    
    curl -s http://localhost:11434/api/generate -d "{
        \"model\": \"$OLLAMA_MODEL\",
        \"prompt\": $(echo "$prompt" | jq -R -s .),
        \"stream\": false
    }" | jq -r '.response' > "$markdown_file"
    
    echo "Markdown report generated: $markdown_file"
}

# Main execution
main() {
    # Parse command line arguments
    parse_args "$@"
    
    # Store original directory
    local original_dir="$PWD"
    WORKING_DIR="$(pwd)"
    
    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo "Error: Not in a git repository"
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
    
    # Initialize JSON array for results
    echo "[]" > "$REVIEW_FILE"
    
    # Process each changed file
    while IFS= read -r file; do
        if [ -n "$file" ]; then
            echo "Reviewing: $file"
            
            # Get diff for the file
            diff=$(get_file_diff "$file")
            
            if [ -n "$diff" ]; then
                # Get AI review
                review=$(query_ollama "$diff")
                severity=$(determine_severity "$review")
                
                # Add to JSON array
                jq --arg file "$file" \
                   --arg review "$review" \
                   --arg severity "$severity" \
                   --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
                   '. += [{
                       "file": $file,
                       "review": $review,
                       "severity": $severity,
                       "timestamp": $timestamp
                   }]' "$REVIEW_FILE" > temp.json && mv temp.json "$REVIEW_FILE"
            fi
        fi
    done < <(get_changed_files)
    
    # Generate markdown report
    generate_markdown "$REVIEW_FILE"
    
    # Return to original directory
    cd "$original_dir" || exit 1
}

# Run the script
main "$@"
