// C entrypoint to avoid Zig linker issues with GCC 15 crt objects
// Calls into Zig code
extern int zig_main(void);

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return zig_main();
}
