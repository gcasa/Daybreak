# Portable developer build; GNUstep is preferred when available.
CC = clang
GNUSTEP_CONFIG ?= gnustep-config
AUTOGSDOC ?= autogsdoc
SANITIZERS ?= address,undefined
CPPFLAGS += -ISource
CFLAGS ?= -O2 -g
OBJCFLAGS += -Wall -Wextra -Werror -std=gnu99
CORE = Source/DBMemory.m Source/DBProcessor.m Source/DBInstructions.m Source/DBControl.m Source/DBProcesses.m Source/DBDisk.m Source/DBMachine.m Source/DBDuchess.m Source/DBBlocks.m Source/DBNetwork.m Source/DBFloppy.m Source/DBFlux.m Source/DBDevices.m
LDLIBS += -lz
HEADERS = $(wildcard Source/*.h) Source/DBInstructionDispatch.inc Source/DBIOInitial.inc
HAVE_GNUSTEP := $(shell command -v $(GNUSTEP_CONFIG) 2>/dev/null)
ifneq ($(HAVE_GNUSTEP),)
OBJCFLAGS += $(shell $(GNUSTEP_CONFIG) --objc-flags) -Wno-expansion-to-defined
LDLIBS += $(shell $(GNUSTEP_CONFIG) --base-libs)
else ifeq ($(shell uname -s),Darwin)
OBJCFLAGS += -fno-objc-arc
LDLIBS += -framework Foundation
else
$(error Install GNUstep Base development files and gnustep-make)
endif

.PHONY: all check clean docs sanitize reference-check
all: build/daybreak
build:
	mkdir -p $@
build/daybreak: $(CORE) Source/main.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Source/main.m -o $@ $(LDLIBS)
build/tests: $(CORE) Tests/EngineTests.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Tests/EngineTests.m -o $@ $(LDLIBS)
build/system-tests: $(CORE) Tests/SystemTests.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Tests/SystemTests.m -o $@ $(LDLIBS)
build/device-tests: $(CORE) Tests/DeviceTests.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Tests/DeviceTests.m -o $@ $(LDLIBS)
check: build/tests build/system-tests build/device-tests build/feature-tests build/daybreak
	./build/tests
	./build/system-tests
	./build/device-tests
	./build/feature-tests
	./build/daybreak --demo
	python3 Tools/check-objc1.py
sanitize:
	$(MAKE) -f Makefile clean
	$(MAKE) -f Makefile CFLAGS='-O1 -g -fsanitize=$(SANITIZERS) -fno-omit-frame-pointer' check
reference-check: build/tests
	python3 Tools/check-reference.py "$(DWARF)"
docs:
	mkdir -p Documentation/API
	$(AUTOGSDOC) -Project Daybreak -HeaderDirectory Source -DocumentationDirectory Documentation/API -IgnoreDependencies YES -Warn YES -DocumentInstanceVariables NO $(wildcard Source/*.h) GUI/DBApplication.h
clean:
	rm -rf build

ifneq ($(HAVE_GNUSTEP),)
GUI_LIBS = $(shell $(GNUSTEP_CONFIG) --gui-libs)
else
GUI_LIBS = -framework AppKit
endif
.PHONY: gui
ifneq ($(HAVE_GNUSTEP),)
gui:
	$(MAKE) -f GNUmakefile.gui
else
gui: build/Daybreak.app/Contents/MacOS/Daybreak build/Daybreak.app/Contents/Info.plist build/Daybreak.app/Contents/Resources/Daybreak.icns build/Daybreak.app/Contents/Resources/disks-6085/.stamp build/Daybreak.app/Contents/Resources/Configurations/.stamp
endif
build/Daybreak.app/Contents/MacOS/Daybreak: $(CORE) GUI/DBApplication.m GUI/main.m GUI/DBApplication.h $(HEADERS)
	mkdir -p build/Daybreak.app/Contents/MacOS
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) -Wno-deprecated-declarations $(CORE) GUI/DBApplication.m GUI/main.m -o $@ $(LDLIBS) $(GUI_LIBS)

build/Daybreak.app/Contents/Info.plist: GUI/Info.plist
	mkdir -p $(@D)
	cp $< $@

build/Daybreak.app/Contents/Resources/Daybreak.icns: GUI/Resources/Daybreak.icns
	mkdir -p $(@D)
	cp $< $@

build/boot-tests: $(CORE) Tests/BootTests.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Tests/BootTests.m -o $@ $(LDLIBS)
.PHONY: boot-check
boot-check: build/boot-tests
	./build/boot-tests "disks-6085/xde5.0.zdisk" 990 build/xde-boot.pbm
	./build/boot-tests "disks-6085/vp2.0.5.zdisk" 8000 build/viewpoint-boot.pbm

build/Daybreak.app/Contents/Resources/disks-6085/.stamp: $(wildcard disks-6085/*)
	mkdir -p $(@D)
	cp disks-6085/* $(@D)/
	touch $@

build/feature-tests: $(CORE) Tests/FeatureTests.m $(HEADERS) | build
	$(CC) $(CPPFLAGS) $(CFLAGS) $(OBJCFLAGS) $(CORE) Tests/FeatureTests.m -o $@ $(LDLIBS)

build/Daybreak.app/Contents/Resources/Configurations/.stamp: $(wildcard Configurations/*)
	mkdir -p $(@D)
	cp Configurations/* $(@D)/
	touch $@
