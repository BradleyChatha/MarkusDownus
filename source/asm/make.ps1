nasm -o libd_win64.obj -Isource/asm -Wall -Ox -f win64 -Dwin64 source/asm/lib.nasm
nasm -o libd_sysv.obj -Isource/asm -Wall -Ox -f elf64 -Dsysv source/asm/lib.nasm