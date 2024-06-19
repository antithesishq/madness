# madness is a meta-loader which, when installed at the default FHS location /lib64/ld-linux-x86-64.so.2 (see ./ld-link.nix)
# will allow programs built with a normal NixOS R(UN)PATH but a FHS program interpreter to run on NixOS, by searching the
# program's RPATH for a loader.

# It's implemented in two stages. madness_stage1 is a C program written without libc (since libc's initialization crashes
# when invoked as a program loader for some reason) that simply `exec`s the stage2 loader passing along its command line.
# madness_stage2_loader.sh is a bash script which further invokes patchelf and which to identify the correct loader and
# then execs it (as a normal program, not a program interpreter) to load the actual program.

# Note that the program to be executed is mapped by the kernel into the process along with the stage1 loader, even though
# it will never run there. In order for this to work reliably the stage1 loader must be build position-independent (-pie)

{pkgs ? (import <nixpkgs> {}),...}:
let
    stage2_loader = pkgs.writeShellScript "madness_stage2_loader.sh" ''
        # echo "[madness] +$0 $@" >&2
        # env >&2
        if [[ "$1" == *-madness_stage1_loader || "$1" == */ld-linux-x86-64.so.2 ]]; then shift; fi
        case $1 in
        /*) EXECUTABLE=$(${pkgs.coreutils}/bin/realpath $1 2> /dev/null) ;;
        *) EXECUTABLE=$(${pkgs.which}/bin/which $1 2> /dev/null) ;;
        esac
        if [ -z "$EXECUTABLE" ]; then echo "[madness] Program $1 is not on the path." >&2; exit 1; fi
        shift
        LOADER=$(PATH=$(${pkgs.patchelf}/bin/patchelf --print-rpath "$EXECUTABLE") ${pkgs.which}/bin/which ld-linux-x86-64.so.2)
        # echo "[madness] Selected loader: $LOADER; Preload: $MD_PRELOAD" >&2 
        export LD_PRELOAD="$MD_PRELOAD"
        export MADNESS_EXECUTABLE_NAME="$EXECUTABLE"
        [ -n "$LOADER" ] || (echo "[madness] Unable to find a loader for executable $EXECUTABLE" >&2; exit 1) && exec "$LOADER" "$EXECUTABLE" "$@"
    '';
    stage1_loader_src = pkgs.writeText "madness_stage1_loader.c" ''
        typedef long ssize_t;
        typedef unsigned long size_t;

        int startswith(const char* value, const char* prefix) {
            while (*prefix) {
                if (*value != *prefix) return 0;
                ++value; ++prefix;
            }
            return 1;
        }

        #define __NR_exit 60
        #define __NR_write 1
        #define __NR_execve 59

        ssize_t syscall3(int call, size_t a, size_t b, size_t c)
        {
            ssize_t ret;
            asm volatile
            (
                "syscall"
                : "=a" (ret)
                : "0"(call), "D"(a), "S"(b), "d"(c)
                : "rcx", "r11", "memory"
            );
            return ret;
        }

        void _start() {
            __asm__(
                ".text \n"
                ".global _start \n"
                "_start: \n"
                "	xor %rbp,%rbp \n"
                "	mov %rsp,%rdi \n"
                "	andq $-16,%rsp \n"
                "	call _start_c \n"
            );
        }

        void _start_c(long *p) {
            int argc = p[0];
            char **argv = (void *)(p+1);
            char **envp = argv + argc + 1;

            if (argc >= 250) {
                syscall3(__NR_write,2,(size_t)"[madness] Too many parameters!\n",0);
                syscall3(__NR_exit,40,0,0);
                return;
            }

            char const* new_argv[256] = { "${stage2_loader}" };
            for(int i=0; i<argc; i++)
                new_argv[i+1] = argv[i];
            new_argv[argc+2] = 0;

            for(char**e = envp; *e; ++e)
                if (startswith(e[0], "LD_PRELOAD=")) {
                    e[0][0]='M';
                }                   

            syscall3(__NR_execve, 
                (size_t)new_argv[0],
                (size_t)new_argv,
                (size_t)envp
            );

            // Normally exec doesn't return, if it does it's some kind of error
            syscall3(__NR_exit,50,0,0);
        }
    '';
    # As of 08/19/2021, madness does not build with the GCC 10 toolchain.
    loader = pkgs.runCommand "madness_stage1_loader" {} ''
        ${pkgs.gcc9}/bin/gcc -fPIC -pie -fno-stack-protector -O2 -nostdlib -nostartfiles ${stage1_loader_src} -o $out
    '';
in {
    inherit loader pkgs;
}