# Native GNUstep make build.  Run make -f GNUmakefile.
GNUSTEP_MAKEFILES ?= $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
ifeq ($(strip $(GNUSTEP_MAKEFILES)),)
include Makefile
else
include $(GNUSTEP_MAKEFILES)/common.make
TOOL_NAME = daybreak
daybreak_OBJC_FILES = Source/DBMemory.m Source/DBProcessor.m \
  Source/DBInstructions.m Source/DBControl.m Source/DBProcesses.m Source/DBDisk.m Source/DBMachine.m Source/DBBlocks.m Source/DBNetwork.m Source/DBFloppy.m Source/DBDevices.m Source/main.m
ADDITIONAL_INCLUDE_DIRS = -ISource
ADDITIONAL_OBJCFLAGS = -Wall -Wextra -std=gnu99
ADDITIONAL_TOOL_LIBS += -lz
include $(GNUSTEP_MAKEFILES)/tool.make

.PHONY: check docs sanitize reference-check
check docs sanitize reference-check::
	$(MAKE) -f Makefile $@
endif
