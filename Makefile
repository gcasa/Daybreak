# Portable developer build; GNUstep is preferred when available.
CC = clang
GNUSTEP_CONFIG ?= gnustep-config
AUTOGSDOC ?= autogsdoc
SANITIZERS ?= address,undefined
CPPFLAGS += -ISource
CFLAGS ?= -O2 -g
OBJCFLAGS += -Wall -Wextra -Werror -std=gnu99
CORE = Source/DBMemory.m Source/DBProcessor.m Source/DBInstructions.m
HEADERS = $(wildcard Source/*.h) Source/DBInstructionDispatch.inc
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
check: build/tests build/daybreak
	./build/tests
	./build/daybreak --demo
	python3 Tools/check-objc1.py
sanitize:
	$(MAKE) -f Makefile clean
	$(MAKE) -f Makefile CFLAGS='-O1 -g -fsanitize=$(SANITIZERS) -fno-omit-frame-pointer' check
reference-check: build/tests
	python3 Tools/check-reference.py "$(DWARF)"
docs:
	mkdir -p Documentation/API
	$(AUTOGSDOC) -Project Daybreak -HeaderDirectory Source -DocumentationDirectory Documentation/API -IgnoreDependencies YES -Warn YES -DocumentInstanceVariables NO Source/DBMemory.h Source/DBProcessor.h Source/DBInstructions.h Source/DBProcessorPrivate.h
clean:
	rm -rf build
