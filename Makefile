SHELL = /bin/bash
TARGET = arm-none-eabi
PREFIX ?= $(HOME)/arm-cs-tools/
PROCS ?= 4
GIT_REV	= $(shell git rev-parse --verify HEAD --short)

CS_BASE		?= 2011.09
CS_REV 		?= 69
GCC_VERSION 	?= 4.6
MPC_VERSION 	?= 0.8.1
SOURCE_PACKAGE	?= 9739
BIN_PACKAGE	?= 9740

CS_VERSION 	= $(CS_BASE)-$(CS_REV)

LOCAL_BASE 	= arm-$(CS_VERSION)-arm-none-eabi
LOCAL_SOURCE 	= $(LOCAL_BASE).src.tar.bz2
LOCAL_BIN 	= $(LOCAL_BASE)-i686-pc-linux-gnu.tar.bz2
SOURCE_URL 	= http://sourcery.mentor.com/sgpp/lite/arm/portal/package$(SOURCE_PACKAGE)/public/arm-none-eabi/$(LOCAL_SOURCE)
BIN_URL 	= http://sourcery.mentor.com/sgpp/lite/arm/portal/package$(BIN_PACKAGE)/public/arm-none-eabi/$(LOCAL_BIN)

SOURCE_MD5_CHCKSUM ?= ebe25afa276211d0e88b7ff0d03c5345
BIN_MD5_CHECKSUM ?= 2f2d73429ce70dfb848d7b44b3d24d3f

BUG_URL ?= https://github.com/jsnyder/arm-eabi-toolchain
PKG_VERSION ?= "ARM EABI 32-bit GNU Toolchain-CS-$(CS_BASE)-$(CS_REV)-$(GIT_REV)"

install-cross: cross-binutils cross-gcc cross-newlib cross-gdb
install-deps: gmp mpfr mpc

sudomode:
ifneq ($(USER),root)
	@echo Please run this target with sudo!
	@echo e.g.: sudo make targetname
	@exit 1
endif

$(LOCAL_SOURCE):
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) curl -LO $(SOURCE_URL)
else
	curl -LO $(SOURCE_URL)
endif

$(LOCAL_BIN):
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) curl -LO $(BIN_URL)
else
	curl -LO $(BIN_URL)
endif

downloadbin: $(LOCAL_BIN)
	@(t1=`openssl md5 $(LOCAL_BIN) | cut -f 2 -d " " -` && \
	test $$t1=$(BIN_MD5_CHECKSUM) || \
	echo "Bad Checksum! Please remove the following file and retry:\n$(LOCAL_BIN)")

downloadsrc: $(LOCAL_SOURCE)
	@(t1=`openssl md5 $(LOCAL_SOURCE) | cut -f 2 -d " " -` && \
	test $$t1=$(SOURCE_MD5_CHECKSUM) || \
	echo "Bad Checksum! Please remove the following file and retry:\n$(LOCAL_SOURCE)")

$(LOCAL_BASE)/%-$(CS_VERSION).tar.bz2 : downloadsrc
ifeq ($(USER),root)
	@(tgt=`tar -jtf $(LOCAL_SOURCE) | grep  $*` && \
	sudo -u $(SUDO_USER) tar -jxvf $(LOCAL_SOURCE) $$tgt)
else
	@(tgt=`tar -jtf $(LOCAL_SOURCE) | grep  $*` && \
	tar -jxvf $(LOCAL_SOURCE) $$tgt)
endif

arm-$(CS_BASE): downloadbin
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) tar -jtf $(LOCAL_BIN) | grep -e '.*cs3.*[ah]$$' -e '.*\.ld' \
	-e '.*.\.inc' | xargs tar -jxvf $(LOCAL_BIN)
else
	tar -jtf $(LOCAL_BIN) | grep -e '.*cs3.*[ah]$$' -e '.*\.ld' \
	 -e '.*.\.inc'  | xargs tar -jxvf $(LOCAL_BIN)
endif

install-bin-extras: arm-$(CS_BASE)
ifeq ($(USER),root)
	pushd arm-$(CS_BASE) ; \
	sudo -u $(SUDO_USER) cp -r arm-none-eabi $(PREFIX) ; \
	popd ;
else
	pushd arm-$(CS_BASE) ; \
	cp -r arm-none-eabi $(PREFIX) ; \
	popd ;
endif

multilibbash: gcc-$(GCC_VERSION)-$(CS_BASE)
	pushd gcc-$(GCC_VERSION)-$(CS_BASE) ; \
	patch -N -p0 < ../patches/gcc-multilib-bash.patch ; \
	popd ;

gcc-$(GCC_VERSION)-$(CS_BASE) : $(LOCAL_BASE)/gcc-$(CS_VERSION).tar.bz2
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) tar -jxf $<
else
	tar -jxf $<
endif

mpc-$(MPC_VERSION) : $(LOCAL_BASE)/mpc-$(CS_VERSION).tar.bz2
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) tar -jxf $<
else
	tar -jxf $<
endif


%-$(CS_BASE) : $(LOCAL_BASE)/%-$(CS_VERSION).tar.bz2
ifeq ($(USER),root)
	sudo -u $(SUDO_USER) tar -jxf $<
else
	tar -jxf $<
endif

gmp: gmp-$(CS_BASE) sudomode
	sudo -u $(SUDO_USER) mkdir -p build/gmp && cd build/gmp ; \
	pushd ../../gmp-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	sudo -u $(SUDO_USER) ../../gmp-$(CS_BASE)/configure --disable-shared && \
	sudo -u $(SUDO_USER) $(MAKE) -j$(PROCS) all && \
	$(MAKE) install

mpc: mpc-$(MPC_VERSION) sudomode
	sudo -u $(SUDO_USER) mkdir -p build/gmp && cd build/gmp ; \
	pushd ../../mpc-$(MPC_VERSION) ; \
	make clean ; \
	popd ; \
	sudo -u $(SUDO_USER) ../../mpc-$(MPC_VERSION)/configure --disable-shared && \
	sudo -u $(SUDO_USER) $(MAKE) -j$(PROCS) all && \
	$(MAKE) install

mpfr: gmp mpfr-$(CS_BASE) sudomode
	sudo -u $(SUDO_USER) mkdir -p build/mpfr && cd build/mpfr && \
	pushd ../../mpfr-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	sudo -u $(SUDO_USER) ../../mpfr-$(CS_BASE)/configure LDFLAGS="-Wl,-search_paths_first" --disable-shared && \
	sudo -u $(SUDO_USER) $(MAKE) -j$(PROCS) all && \
	$(MAKE) install

cross-binutils: binutils-$(CS_BASE)
	mkdir -p build/binutils && cd build/binutils && \
	pushd ../../binutils-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../binutils-$(CS_BASE)/configure --prefix=$(PREFIX)		\
	--target=$(TARGET) --with-pkgversion=$(PKG_VERSION)		\
	--with-bugurl=$(BUG_URL) --disable-nls --disable-werror && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-host install-target

CS_SPECS='--with-specs=%{save-temps: -fverbose-asm}		\
-D__CS_SOURCERYGXX_MAJ__=2011 -D__CS_SOURCERYGXX_MIN__=9	\
-D__CS_SOURCERYGXX_REV__=69 %{O2:%{!fno-remove-local-statics:	\
-fremove-local-statics}}					\
%{O*:%{O|O0|O1|O2|Os:;:%{!fno-remove-local-statics:		\
-fremove-local-statics}}}'

cross-gcc-first: cross-binutils gcc-$(GCC_VERSION)-$(CS_BASE) multilibbash
	mkdir -p build/gcc-first && cd build/gcc-first && \
	pushd ../../gcc-$(GCC_VERSION)-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../gcc-$(GCC_VERSION)-$(CS_BASE)/configure			\
	--prefix=$(PREFIX) --with-pkgversion=$(PKG_VERSION)		\
	--with-bugurl=$(BUG_URL) --target=$(TARGET) $(DEPENDENCIES)	\
	--disable-libquadmath --enable-languages="c" --with-gnu-ld	\
	--with-gnu-as --with-newlib --disable-nls --disable-libssp	\
	--with-newlib --without-headers --disable-shared		\
	--disable-threads --disable-libmudflap --disable-libgomp	\
	--disable-libstdcxx-pch --disable-libunwind-exceptions		\
	--disable-libffi --enable-extra-sgxxlite-multilibs $(CS_SPECS) && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-target && \
	$(MAKE) -C gcc install-common install-cpp install- install-driver install-headers

cross-gcc: cross-binutils cross-gcc-first cross-newlib gcc-$(GCC_VERSION)-$(CS_BASE) multilibbash
	mkdir -p build/gcc-final && cd build/gcc-final && \
	../../gcc-$(GCC_VERSION)-$(CS_BASE)/configure			\
	--prefix=$(PREFIX) --with-pkgversion=$(PKG_VERSION)		\
	--with-bugurl=$(BUG_URL) --target=$(TARGET) $(DEPENDENCIES)	\
	--enable-languages="c,c++" --with-gnu-ld --with-gnu-as		\
	--with-newlib --disable-nls --disable-libssp --with-newlib	\
	--disable-shared --disable-threads --with-headers=yes		\
	--disable-libmudflap --disable-libgomp				\
	--disable-libstdcxx-pch --disable-libffi			\
	--enable-extra-sgxxlite-multilibs $(CS_SPECS) && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-target && \
	$(MAKE) -C gcc install-common install-cpp install- install-driver install-headers

NEWLIB_FLAGS="-ffunction-sections -fdata-sections			\
-DPREFER_SIZE_OVER_SPEED -D__OPTIMIZE_SIZE__ -Os -fomit-frame-pointer	\
-fno-unroll-loops -D__BUFSIZ__=256 -mabi=aapcs"

cross-newlib: cross-binutils cross-gcc-first newlib-$(CS_BASE)
	mkdir -p build/newlib && cd build/newlib && \
	pushd ../../newlib-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../newlib-$(CS_BASE)/configure --prefix=$(PREFIX)	\
	--target=$(TARGET) --disable-newlib-supplied-syscalls	\
	--disable-libgloss --disable-nls --disable-shared	\
	--enable-newlib-io-long-long --enable-newlib-register-fini && \
	$(MAKE) -j$(PROCS) CFLAGS_FOR_TARGET=$(NEWLIB_FLAGS) CCASFLAGS=$(NEWLIB_FLAGS) && \
	$(MAKE) install

cross-gdb: gdb-$(CS_BASE)
	mkdir -p build/gdb && cd build/gdb && \
	pushd ../../gdb-$(CS_BASE) ; \
	make clean ; \
	popd ; \
	../../gdb-$(CS_BASE)/configure --prefix=$(PREFIX) --target=$(TARGET) --with-pkgversion=$(PKG_VERSION) --with-bugurl=$(BUG_URL) --disable-werror && \
	$(MAKE) -j$(PROCS) && \
	$(MAKE) installdirs install-host install-target

.PHONY : clean
clean:
	rm -rf build *-$(CS_BASE) binutils-* gcc-* gdb-* newlib-* $(LOCAL_BASE)
