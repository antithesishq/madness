# madness is a meta-loader which, when installed at the default FHS location /lib64/ld-linux-x86-64.so.2 (see ./ld-link.nix)
# will allow programs built with a normal NixOS R(UN)PATH but a FHS program interpreter to run on NixOS, by searching the
# program's RPATH for a loader.

# It's implemented in two stages. madness_stage1 is a C program written without libc (since libc's initialization crashes
# when invoked as a program loader for some reason) that simply `exec`s the stage2 loader passing along its command line.
# madness_stage2_loader.sh is a bash script which further invokes patchelf and which to identify the correct loader and
# then execs it (as a normal program, not a program interpreter) to load the actual program.

# Note that the program to be executed is mapped by the kernel into the process along with the stage1 loader, even though
# it will never run there. In order for this to work reliably the stage1 loader must be build position-independent (-pie)

{writeText, writeShellScript, coreutils, which, patchelf, runCommand, gcc, gnugrep}:
let
    stage2_loader = writeShellScript "madness_stage2_loader.sh" ''
        # echo "[madness] +$0 $@" >&2
        # env >&2
        if [[ "$1" == *-madness_stage1_loader || "$1" == */ld-linux-x86-64.so.2 ]]; then shift; fi
        case $1 in
        /*) EXECUTABLE=$(${coreutils}/bin/realpath $1 2> /dev/null) ;;
        *) EXECUTABLE=$(${which}/bin/which $1 2> /dev/null) ;;
        esac
        if [ -z "$EXECUTABLE" ]; then echo "[madness] Program $1 is not on the path." >&2; exit 1; fi
        shift
        LOADER=$(PATH=$(${patchelf}/bin/patchelf --print-rpath "$EXECUTABLE") ${which}/bin/which ld-linux-x86-64.so.2)
        if [[ "$LOADER" == "" && "$MADNESS_ALLOW_LDD" != "" ]]; then LOADER=$(ldd "$EXECUTABLE" | ${gnugrep}/bin/grep /lib64/ld-linux-x86-64.so.2 | ${coreutils}/bin/cut -f 2 | ${coreutils}/bin/cut -d ' ' -f 3); fi
        # echo "[madness] Selected loader: $LOADER; Preload: $MD_PRELOAD" >&2 
        export LD_PRELOAD="$MD_PRELOAD"
        export MADNESS_EXECUTABLE_NAME="$EXECUTABLE"
        [ -n "$LOADER" ] || (echo "[madness] Unable to find a loader for executable $EXECUTABLE" >&2; exit 1) && exec "$LOADER" "$EXECUTABLE" "$@"
    '';
    stage1_loader_src = ./madness_stage1_loader.c;
    # As of 08/19/2021, madness does not build with the GCC 10 toolchain.
    madness_loader = runCommand "madness_stage1_loader" {} ''
        ${gcc}/bin/gcc -fPIC -pie -fno-stack-protector -O2 -nostdlib -nostartfiles -ffreestanding -DSTAGE2_LOADER=\"${stage2_loader}\" ${stage1_loader_src} -o $out
    '';
in {
    inherit madness_loader;
    loader = madness_loader;
}
