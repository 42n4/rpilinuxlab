# Raspberry Pi Lab

Raspberry Pi Lab przygotowane na podstawie 
1) https://wiki.gentoo.org/wiki/Cross_build_environment
2) http://mgalgs.github.io/2015/05/16/how-to-build-a-custom-linux-kernel-for-qemu-2015-edition.html
3) środowiska Pawła Kraszewskiego z fragmentami z jego README

Przygotowanie środowiska programistycznego do procesorów ARM po system Gentoo
"na piechotę":

Ścieżki w plikach .config przeznaczone są dla tego opisu poniżej. Dla przepisu
w "Makefile" trzeba je poprawić.

1. Instalacja pakietu CROSSDEV

------CUT----------------------------------------------------------------------
emerge -av crossdev
------CUT----------------------------------------------------------------------

2. Generacja narzędzi dla platformy ARM

crossdev --target arm-softfloat-linux-gnueabi --gcc 4.9.3 --libc 2.23 --kernel 4.7.5

------CUT----------------------------------------------------------------------

3. Skrypt "armmake" wywołuje "make" z ustawieniem parametrów do kross-kompilacji
   narzędziami z p. 2

------CUT----------------------------------------------------------------------
#!/bin/bash
export ARCH=arm
export CROSS_COMPILE=arm-softfloat-linux-gnueabi-
make $@
------CUT----------------------------------------------------------------------

4. Ściągamy i rozpakowujemy źródła kernela i busybox do podkatalogu src

------CUT----------------------------------------------------------------------
mkdir -p src bin.kernel bin.busybox out.initrd emulacja
wget http://www.kernel.org/pub/linux/kernel/v3.0/linux-3.1.4.tar.bz2
wget http://busybox.net/downloads/busybox-1.19.3.tar.bz2
tar xjf linux-3.1.4.tar.bz2 -C src
tar xjf busybox-1.19.3.tar.bz2 -C src
------CUT----------------------------------------------------------------------

5. Konfigurujemy kernel

------CUT----------------------------------------------------------------------
cd src/linux-3.1.4
../../armmake O=../../bin.kernel menuconfig
cd ../..
------CUT----------------------------------------------------------------------

6. Kompilujemy kernel

------CUT----------------------------------------------------------------------
cd bin.kernel
../armmake all
cd ..
------CUT----------------------------------------------------------------------

6. Konfigurujemy busybox

------CUT----------------------------------------------------------------------
cd src/busybox-1.19.3
../../armmake O=../../bin.busybox menuconfig
cd ../..
------CUT----------------------------------------------------------------------

7. Kompilujemy busybox

------CUT----------------------------------------------------------------------
cd bin.busybox
../armmake
../armmake install
cd ..

------CUT----------------------------------------------------------------------

8. Dopieszczamy INITRD

9. Generujemy obraz INITRD

------CUT----------------------------------------------------------------------
cd out.initrd
find . | cpio --quiet -H newc -o --owner=0.0 > ../emulacja/initrd
cd ..
------CUT----------------------------------------------------------------------

10. Linkujemy obraz jądra

------CUT----------------------------------------------------------------------
ln -s ../bin.kernel/arch/arm/boot/zImage emulacja/vmlinuz
------CUT----------------------------------------------------------------------

11. Odpalamy emulator

------CUT----------------------------------------------------------------------
qemu-system-arm -M versatilepb -m 256 -kernel emulacja/vmlinuz -initrd emulacja/initrd -append "root=/dev/ram0"
------CUT----------------------------------------------------------------------

12. Najlepiej jednak skorzystać z załączonych Makefile'ów dla x86_64, armsoft i raspberry2 armvh7

make emulate

i to by było na tyle!
