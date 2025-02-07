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
