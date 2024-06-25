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

## How does this interact with the new options in NixOS 24.05

NixOS 24.05 added an option to enable a stub LD (see the [release notes](https://nixos.org/manual/nixos/stable/release-notes#sec-release-24.05-highlights)). This is conceptually similar to Madness, except that rather than try to run your program, it instead prints an error message and refuses to run your program. This is leaps and bounds better than the pre-24.05 situation, where you got an *utterly incomprehensible* error, but we still prefer Madness. If you're running on 24.05, Madness will disable this feature.

## What about the nix-ld project?

[nix-ld](https://github.com/Mic92/nix-ld) is a project that is once again very similar to Madness conceptually. The difference is that rather than trying to auto-detect which *version* of `ld` to grab from your Nix store, it requires you to specify one with the `NIX_LD` environment variable. There are pros and cons to both approaches. We like the convenience of auto-detection, and have found that it works pretty well.

## Does this handle things like LD_PRELOAD correctly?

Yup! This isn't the most exhaustively tested feature, but Madness does handle this, and we use it in this mode every day.

## But how do I actually build an executable that will work both places?

This is a little beyond the scope of this project, but here are some tips:

* If you're building your software on a non-NixOS Linux, there's a good chance that it will Just Work (TM) on Madness-enabled NixOS. If you see errors about missing libraries, try running in a Nix shell that provides those libraries, or try wrapping the binary in a script that exports them with `LD_LIBRARY_PATH`. Obviously the closer you get to something statically linked, or linking only libc, the easier this will be.

* If you're building you software on NixOS, you have to do a few tricks. 
  - The one actually related to this project is that you should use the [patchelf]() tool to set the hardcoded loader/linker location to the one that works on non-NixOS machines, not the one that points to the Nix store. Something like this: `${pkgs.patchelf}/bin/patchelf $out/myProgram --set-interpreter /lib64/ld-linux-x86-64.so.2`. Then Madness, will make the resulting binary work on NixOS too.
  - You also probably need to deal with a cluster of issues around glibc versioning. NixOS tends to have a bleeding edge glibc, which means that when you link your program it may pick up [version symbols](https://peeterjoot.com/2019/09/20/an-example-of-linux-glibc-symbol-versioning/) that are not available on the version of Linux your program runs on. You can get around this by linking against an old version of glibc, or you can try using a [linker script](https://ftp.gnu.org/old-gnu/Manuals/ld-2.9.1/html_node/ld_25.html). Note also that the very newest versions of glibc have [changed how certain auxiliary libraries are packaged](https://developers.redhat.com/articles/2021/12/17/why-glibc-234-removed-libpthread), which may require you to screw around with `DT_NEEDED` as well. You can also get around this whole category of stuff by statically linking your binary using an alternative libc such as [musl](https://www.musl-libc.org/).
