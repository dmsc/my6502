
TARGET ?= upduino

PACKAGE=sg48
DEVICE=5k
SPEED=up

BUILDDIR=build

# Sources:
TESTS=\
      uart \
      timer \
      system \
      upduino_post \

RTL=\
    rtl/ALU.v\
    rtl/cpu.v\
    rtl/minirom.v\
    rtl/pll.v\
    rtl/ram.v\
    rtl/rgbled.v\
    rtl/system.v\
    rtl/timer.v\
    rtl/uart.v\
    rtl/vga.v\

# Clock constrains for packer:
SDC_FILE=clk-pre.sdc

HEXFILE=$(BUILDDIR)/minirom.hex

all: $(TARGET)

.PHONY: test
test: $(TESTS:%=$(BUILDDIR)/%.vcd)

.PHONY: $(TARGET)
$(TARGET): %: $(BUILDDIR)/%.bin $(BUILDDIR)/%.time

$(BUILDDIR)/%.blif: rtl/%.v | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -top $* -blif $@' -l $(@:.blif=-yosys.log) $(filter %.v, $^) \
	    && sed -n -e '/^[1-9].*statistics/,/^[1-9]/p' $(@:.blif=-yosys.log)

$(BUILDDIR)/%.json: rtl/%.v | $(BUILDDIR)
	yosys -q -p 'synth_ice40 -top $* -json $@' -l $(@:.json=-yosys.log) $(filter %.v, $^) \
	    && sed -n -e '/^[1-9].*statistics/,/^[1-9]/p' $(@:.json=-yosys.log)

# Place using ARACHNE-PNR
#$(BUILDDIR)/%.asc: $(BUILDDIR)/%.blif  rtl/%.pcf
#	arachne-pnr -d $(DEVICE) -P $(PACKAGE) -p rtl/$*.pcf -o $@ $<

# Place using NEXTPNR
$(BUILDDIR)/%.asc: $(BUILDDIR)/%.json  rtl/%.pcf
	nextpnr-ice40 --pre-pack $(SDC_FILE) \
	              --$(SPEED)$(DEVICE) --json $< --pcf rtl/$*.pcf --asc $@

$(BUILDDIR)/%.bin: $(BUILDDIR)/%.asc
	icepack $< $@

# Timing report
$(BUILDDIR)/%.time: $(BUILDDIR)/%.asc rtl/%.pcf
	icetime -m -t -P $(PACKAGE) -p rtl/$*.pcf -d $(SPEED)$(DEVICE) -r $@ $<

# Post-synthesis verilog - from BLIF
#$(BUILDDIR)/%_syn.v: $(BUILDDIR)/%.blif
#	yosys -o $@ -p 'read_blif -wideports $<'

# Post-synthesis verilog - from JSON
$(BUILDDIR)/%_syn.v: $(BUILDDIR)/%.json
	yosys -o $@ -p 'read_json $<'

# Post synthesis simulator
$(BUILDDIR)/%_post_test: tests/%_post_tb.v $(BUILDDIR)/%_syn.v
	# Filter out PLL cell to allow simulation
	sed -i 's/ SB_PLL40_CORE/ TB_SB_PLL40_CORE/' $(BUILDDIR)/$*_syn.v
	iverilog -g2012 -o $@ -D POST_SYNTHESIS $< $(BUILDDIR)/$*_syn.v  \
	    `yosys-config --datdir/ice40/cells_sim.v`

# Module simulator
$(BUILDDIR)/%_test: tests/%_tb.v rtl/%.v | $(BUILDDIR)
	iverilog -g2012 -o $@ $(filter %.v , $^) `yosys-config --datdir/ice40/cells_sim.v`

# Run simulation
$(BUILDDIR)/%.vcd: $(BUILDDIR)/%_test
	vvp $< +vcd=$@

# Assemble sources
asm/minirom.obx: asm/minirom.asm
	mads $<

$(BUILDDIR)/minirom.hex: asm/minirom.obx | $(BUILDDIR)
	od -An -tx1 -w1 -v $< > $@

# Make folders
$(BUILDDIR):
	mkdir -p $(BUILDDIR)

clean:
	rm -rf $(BUILDDIR)


.PRECIOUS: $(BUILDDIR)/%.blif $(BUILDDIR)/%.json $(BUILDDIR)/%.asc $(BUILDDIR)/%_syn.v

# Dependencies
$(BUILDDIR)/system.json: $(RTL)
$(BUILDDIR)/system.blif: $(RTL)
$(BUILDDIR)/system_test: $(RTL)

$(BUILDDIR)/upduino.json: $(RTL)
$(BUILDDIR)/upduino.blif: $(RTL)
$(BUILDDIR)/upduino_test: $(RTL)

$(BUILDDIR)/system_test: $(HEXFILE)
$(BUILDDIR)/system.blif: $(HEXFILE)
$(BUILDDIR)/system.json: $(HEXFILE)
$(BUILDDIR)/upduino_test: $(HEXFILE)
$(BUILDDIR)/upduino.blif: $(HEXFILE)
$(BUILDDIR)/upduino.json: $(HEXFILE)

