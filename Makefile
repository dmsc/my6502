
TARGET ?= my6502

PACKAGE=sg48
DEVICE=5k
SPEED=up

BUILDDIR=build

# Sources:
TESTS=\
      uart \
      timer \

RTL=\
    rtl/ALU.v\
    rtl/cpu.v\
    rtl/minirom.v\
    rtl/system.v\
    rtl/timer.v\
    rtl/uart.v\

all: $(TARGET)

.PHONY: test
test: $(TESTS:%=$(BUILDDIR)/%.vcd)

.PHONY: $(TARGET)
$(TARGET): %: $(BUILDDIR)/%.bin $(BUILDDIR)/%.time

$(BUILDDIR)/$(TARGET).blif: $(RTL) | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -top system -blif $@' -l $(@:.blif=-yosys.log) $^ \
	    && sed -n -e '/^[2-9].*statistics/,/^[2-9]/p' $(@:.blif=-yosys.log)

$(BUILDDIR)/$(TARGET).json: $(RTL) | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -top system -json $@' -l $(@:.json=-yosys.log) $^ \
	    && sed -n -e '/^[2-9].*statistics/,/^[2-9]/p' $(@:.json=-yosys.log)

$(BUILDDIR)/%.blif: rtl/%.v | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -blif $@' -l $(@:.blif=-yosys.log) $< \
	    && sed -n -e '/^2.*statistics/,/^2/p' $(@:.blif=-yosys.log)

$(BUILDDIR)/%.json: rtl/%.v | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -json $@' -l $(@:.json=-yosys.log) $< \
	    && sed -n -e '/^2.*statistics/,/^2/p' $(@:.json=-yosys.log)

# Place using ARACHNE-PNR
$(BUILDDIR)/%.asc: $(BUILDDIR)/%.blif  rtl/%.pcf
	arachne-pnr -d $(DEVICE) -P $(PACKAGE) -p rtl/$*.pcf -o $@ $<

# Place using NEXTPNR
#$(BUILDDIR)/%.asc: $(BUILDDIR)/%.json  rtl/%.pcf
#	nextpnr-ice40 --$(SPEED)$(DEVICE) --json $< --pcf rtl/$*.pcf --asc $@

$(BUILDDIR)/%.bin: $(BUILDDIR)/%.asc
	icepack $< $@

# Timing report
$(BUILDDIR)/%.time: $(BUILDDIR)/%.asc rtl/%.pcf
	icetime -m -t -P $(PACKAGE) -p rtl/$*.pcf -d $(SPEED)$(DEVICE) -r $@ $<

# Post-synthesis verilog - from BLIF
$(BUILDDIR)/%_syn.v: $(BUILDDIR)/%.blif
	yosys -o $@ $<

# Post-synthesis verilog - from JSON
$(BUILDDIR)/%_syn.v: $(BUILDDIR)/%.json
	yosys -o $@ $<

# Post synthesis simulator
$(BUILDDIR)/%_test: tests/%_post_tb.v $(BUILDDIR)/%_syn.v
	iverilog -o $@ -D POST_SYNTHESIS $< $(BUILDDIR)/$*_syn.v  \
	    `yosys-config --datdir/ice40/cells_sim.v`

# Module simulator
$(BUILDDIR)/%_test: tests/%_tb.v rtl/%.v | $(BUILDDIR)
	iverilog -g2012 -o $@ $^

# Run simulation
$(BUILDDIR)/%.vcd: $(BUILDDIR)/%_test
	vvp $< +vcd=$@

# Make folders
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

clean:
	rm -rf $(BUILDDIR)


.PRECIOUS: $(BUILDDIR)/%.blif $(BUILDDIR)/%.json $(BUILDDIR)/%.asc $(BUILDDIR)/%_syn.v

