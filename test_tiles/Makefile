###############################################################################
# Makefile for Square Kernel test
###############################################################################

## General Flags
PROJECT = SQSprtst
INFO    = gameinfo.properties
MCU     = atmega644
CC      = avr-gcc
OBJDIR  = obj
DEPDIR  = dep
BINDIR  = bin
BNDDIR  = bundle
DIRS    = $(OBJDIR) $(DEPDIR) $(BINDIR)
GAME    = $(BINDIR)/$(PROJECT)
TARGET  = $(GAME).elf

## Kernel settings
KERNEL_DIR = ../kernel
KERNEL_OPTIONS  =

## Packrom (.uze)
PACKROM_DIR = ../packrom


## Options common to compile, link and assembly rules
COMMON = -mmcu=$(MCU)

## Compile options common for all C compilation units.
CFLAGS  = $(COMMON)
CFLAGS += -Wall -gdwarf-2 -std=gnu99 -DF_CPU=28636360UL -O2 -fsigned-char
CFLAGS += -ffunction-sections -fno-toplevel-reorder -fno-tree-switch-conversion
CFLAGS += -MD -MP -MT $(*F).o -MF $(DEPDIR)/$(@F).d
CFLAGS += $(KERNEL_OPTIONS)
CFLAGS += -DVERSION=0x$(VERSION)


## Assembly specific flags
ASMFLAGS  = $(COMMON)
ASMFLAGS += $(CFLAGS)
ASMFLAGS += -x assembler-with-cpp -Wa,-gdwarf2

## Linker flags
LDFLAGS  = $(COMMON)
LDFLAGS += -Wl,-Map=$(GAME).map
LDFLAGS += -Wl,-gc-sections
LDFLAGS += -T$(KERNEL_DIR)/sq_lkscript.x


## Intel Hex file production flags
HEX_FLASH_FLAGS  = -R .eeprom


## Objects that must be built in order to link
OBJECTS  = $(OBJDIR)/sq_kernel.o
OBJECTS += $(OBJDIR)/main.o
OBJECTS += $(OBJDIR)/tiles.o
OBJECTS += $(OBJDIR)/tiles_txt.o

## Include Directories
INCLUDES = -I"$(KERNEL_DIR)"

## Build
all: $(TARGET) $(GAME).hex $(GAME).lss $(BNDDIR) size

## Directories
$(OBJDIR):
	mkdir $(OBJDIR)

$(DEPDIR):
	mkdir $(DEPDIR)

$(BINDIR):
	mkdir $(BINDIR)


## Compile Kernel files
$(OBJDIR)/sq_kernel.o: $(KERNEL_DIR)/sq_kernel.s | $(DIRS)
	$(CC) $(INCLUDES) $(ASMFLAGS) -c $< -o $@

## Compile game sources
$(OBJDIR)/main.o: main.c | $(DIRS)
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@

$(OBJDIR)/tiles.o: tiles.c tiles.h | $(DIRS)
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@

$(OBJDIR)/tiles_txt.o: tiles_txt.c tiles_txt.h | $(DIRS)
	$(CC) $(INCLUDES) $(CFLAGS) -c $< -o $@


## Link
$(TARGET): $(OBJECTS) | $(DIRS)
	$(CC) $(LDFLAGS) $(OBJECTS) $(LIBDIRS) $(LIBS) -o $(TARGET)

%.hex: $(TARGET)
	avr-objcopy -O ihex $(HEX_FLASH_FLAGS) $< $@

%.lss: $(TARGET)
	avr-objdump -h -D -S $< > $@

%.uze: $(TARGET)
	-$(PACKROM_DIR)/packrom $(GAME).hex $@ $(INFO)


## Create bundle
$(BNDDIR): $(GAME).uze
	-mkdir -p $(BNDDIR)
	-cp $(GAME).uze $(BNDDIR)
	-cp resource/*.dat $(BNDDIR)


UNAME := $(shell sh -c 'uname -s 2>/dev/null || echo not')
AVRSIZEFLAGS := -A ${TARGET}
ifneq (,$(findstring MINGW,$(UNAME)))
AVRSIZEFLAGS := -C --mcu=${MCU} ${TARGET}
endif

size: ${TARGET}
	@echo
	@avr-size ${AVRSIZEFLAGS}

## Clean target
.PHONY: clean
clean:
	-rm -rf $(DIRS)
	-rm -rf $(BNDDIR)
	-rm -f  $(GAME).*
