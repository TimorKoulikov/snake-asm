

all:
	nasm -f bin snake.asm -o snake.bin
run:
	qemu-system-i386 -drive format=raw,file=snake.bin
gdb:
	qemu-system-i386 -drive format=raw,index=0,if=floppy,file=snake.bin -s -S
gdb-run:
	gdb.exe -ix "gdb_init_real_mode.txt" -ex "set tdesc filename target.xml" -ex "target remote localhost:1234" -ex "br *0x7c00" -ex "c"