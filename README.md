# review-this

`review-this` is a command-line tool that provides automated code review feedback using Ollama's AI models. It analyzes git changes (either unstaged or between branches) and generates detailed review comments about potential issues, best practices, and improvements.

This is just a fun project I've been working with. To run:

## Features

- Analyze unstaged changes or compare branches
- Customizable AI model prompts through Modelfiles
- Generate review reports in both JSON and Markdown formats
- Exclude common configuration files automatically
- Support for reviewing new (untracked) files
- Debug mode for troubleshooting
- Configurable model temperature for response generation

## Prerequisites

- git
- curl
- jq
- Ollama running locally with the codellama model

## Installation

1. Ensure you have all prerequisites installed
2. Clone this repository or download the script
3. Make the script executable:
   ```bash
   chmod +x review-this
   ```
4. Place the script in your PATH (optional):
   ```bash
   sudo ln -s $(pwd)/review-this /usr/local/bin/
   ```

## Basic Usage

Review unstaged changes in the current repository:

```bash
review-this
```

Compare with a specific branch:

```bash
review-this --mode branch --branch main
```

## Command Line Options

```
--mode, -m          Compare mode: 'current' (unstaged changes) or 'branch' (compare with branch)
--branch, -b        Branch to compare against (default: develop)
--model, -ml        Ollama model to use (default: codellama)
--temperature, -t   Model temperature (default: 0.7, range: 0-2)
--modelfile, -mf    Path to custom Modelfile with review prompt
--debug, -d         Enable debug output
```

## Customizing Reviews with Modelfiles

You can customize the review behavior by creating a Modelfile with your own prompt. This allows you to define specific review criteria, response format, and focus areas.

### Example Modelfile

```modelfile
FROM codellama

SYSTEM """
You are a code reviewer analyzing a git diff. Please evaluate the code for:
- Security vulnerabilities
- Performance issues
- Code quality and best practices
- Potential bugs
- Documentation completeness

Format your response as follows:
1. CRITICAL: List any security or major issues
2. WARNINGS: List performance concerns or potential bugs
3. SUGGESTIONS: List style and documentation improvements
4. If no issues found, respond with "LGTM" (Looks Good To Me)

Each issue should include:
- Issue description
- Location or context
- Recommended fix
"""
```

To use a custom Modelfile:

```bash
review-this --modelfile path/to/your/modelfile
```

## Output

The script generates two types of output files:

1. `review_results.json`: Contains the raw review data in JSON format
2. `review_results.md`: A formatted Markdown report of the review findings

### Sample JSON Output

```json
[
  {
    "file": "src/main.js",
    "review": "• Missing error handling in async function\n• Unused variable 'config' on line 23",
    "timestamp": "2024-02-07T15:30:45Z"
  }
]
```

## Debug Mode

Enable debug mode to get detailed logging:

```bash
review-this --debug
```

Debug logs are written to `git-review-debug.log` in the working directory.

## Known Limitations

- Only works with text-based files
- Requires Ollama to be running locally
- Large diffs may take longer to process
- Memory usage scales with diff size
- Some models behave differently, so the resulting markdown file might be a bit different. For example, `deepseek-r1` has reasoning in the response in between the `<think></think>` tags. I couldn't figure out a way of omiting those.
- I'll update when I see more

## Contributing

Feel free to open issues or submit pull requests for:

- Bug fixes
- New features
- Documentation improvements
- Example Modelfiles

## License

[MIT License](LICENSE)
