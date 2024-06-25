# Introduction

Madness is a tool that was developed within [Antithesis](https://antithesis.com) to make it easier to run the same piece of software on both [NixOS](https://nixos.org) and on conventional Linux distributions. This is purely an internal tool that we're open-sourcing to help others, it is not required in any way to use Antithesis.

When you compile a native executable, it hardcodes the location to the ELF program loader, which is a utility provided by your operating system to start executing a program. On most modern Linux distributions, this utility is called [ld-linux.so](https://linux.die.net/man/8/ld-linux.so) and lives in the `/lib/` or `/lib64/` directory.

NixOS works differently. A binary compiled on NixOS will instead hardcode a particular *version* of `ld-linux.so` living under a particular Nix store path. This means that if you take that binary and run it on a different version of Linux, it won't work. But the reverse is also true -- binaries compiled for other versions of Linux will not generally work on NixOS without modification.

Madness solves this problem for you. If you install Madness on your NixOS computer, it will create a virtual loader that lives at the standard locations used by non-NixOS systems. That virtual loader will then examine your binary, and pick a real loader out of the Nix store to use. This means that you can now build software that works on NixOS, and deploy the exact same binary on non-NixOS computers, and have it work in both locations.

# How Do I Use This?

First add the following to your list of module imports:

```
"${builtins.fetchGit { url = "https://github.com/antithesishq/madness.git"; }}/modules"
```

The module can then be turned on by setting `madness.enable = true;` in your NixOS configuration.

# FAQ
