# review-this

A Git diff automated code review using Ollama :)

This is just a fun project I've been working with. To run:

```sh
# Run the install script
./install.sh

# Now the script should be accessible anywhere on your machine, to use it:
review-this

# You can run in debug mode to view what's going on
review-this --debug

# You can configure the temperature, and the model to use
review-this --temperature 2.0 --model deepseek-r1:14b

# To view more options
review-this --help
```

# Output

This script will read your `git diff` and generate 2 files:

### review_results.json

A JSON file which you can update the code to generate more metadata, this JSON will be used to feed the other agent in the next steps, but it should provide enough information to programatically do something with the code review already

### review_results.md

A Markdown file with the findings from the previous JSON file. This should be useful in case you need to programatically add these comments somewhere (a PR maybe?)

# Caveats

- Some models behave differently, so the resulting markdown file might be a bit different. For example, `deepseek-r1` has reasoning in the response in between the `<think></think>` tags. I couldn't figure out a way of omiting those.
- I'll update when I see more
