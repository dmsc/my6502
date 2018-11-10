
TARGET ?= my6502

PACKAGE=sg48
DEVICE=5k
SPEED=up

BUILDDIR=build

# Sources:
TESTS=\
      uart \


all: $(TARGET)

.PHONY: test
test: $(TESTS:%=$(BUILDDIR)/%.vcd)

.PHONY: $(TARGET)
$(TARGET): %: $(BUILDDIR)/%.bin $(BUILDDIR)/%.time

$(BUILDDIR)/%.blif: rtl/%.v | $(BUILDDIR)
	yosys -p 'synth_ice40 -blif $@' $<

$(BUILDDIR)/%.json: rtl/%.v | $(BUILDDIR)
	yosys -p 'synth_ice40 -json $@' $<

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

