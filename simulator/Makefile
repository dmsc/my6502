#
#  Mini65 - Small 6502 simulator with Atari 8bit bios.
#  Copyright (C) 2017-2019 Daniel Serpell
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program.  If not, see <http://www.gnu.org/licenses/>
#

BDIR=build

CC=gcc
INCLUDES=-I$(BDIR)
CFLAGS=$(INCLUDES) -O3 -Wall -g -flto
LDLIBS=-lm -lpthread
ODIR=$(BDIR)/obj

all: $(BDIR)/my6502sim

SRC=\
 src/hw.c\
 src/main.c\
 src/sim65.c\

OBJS=$(SRC:src/%.c=$(ODIR)/%.o)

$(BDIR)/my6502sim: $(OBJS) | $(BDIR)
	$(CC) $(CFLAGS) -o $@ $^ $(LDLIBS)

$(ODIR)/%.o: src/%.c | $(ODIR)
	$(CC) $(CFLAGS) -c -o $@ $<

# Generate header file from minirom binary and labels
$(BDIR)/minirom.h: ../build/minirom.bin
	xxd -i $< $@

$(BDIR)/minirom_lbl.h: ../build/minirom.lbl get_labels.awk
	awk -f get_labels.awk $< > $@

$(BDIR):
$(ODIR):
	mkdir -p $@

$(ODIR)/hw.o: src/hw.c src/hw.h src/sim65.h
$(ODIR)/main.o: src/main.c src/sim65.h src/hw.h $(BDIR)/minirom.h $(BDIR)/minirom_lbl.h
$(ODIR)/sim65.o: src/sim65.c src/sim65.h
