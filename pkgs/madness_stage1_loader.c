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

    char const* new_argv[256] = { STAGE2_LOADER };
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
