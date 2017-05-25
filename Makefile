snake.bin: snake.asm
	nasm snake.asm -f bin -o snake.bin

snake.img: snake.bin
	dd if=/dev/null of=snake.img count=1 bs=512
	dd if=snake.bin of=snake.img conv=notrunc
	#touch run

run: snake.img
	qemu-system-x86_64 -fda snake.bin

clean:
	rm *.bin *.img run
