# Introduction

Madness is a tool that was developed within Antithesis to make it easier to run the same piece of software on both NixOS and on conventional Linux distributions.

# How Do I Use This?

First add the following to your list of module imports:

```
"${builtins.fetchGit { url = "https://github.com/antithesishq/madness.git"; }}/modules"
```

The module can then be turned on by setting `madness.enable = true;` in your NixOS configuration.

# FAQ