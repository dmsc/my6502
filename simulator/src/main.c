/*
 * Mini65 - Small 6502 simulator with Atari 8bit bios.
 * Copyright (C) 2017-2019 Daniel Serpell
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License along
 * with this program.  If not, see <http://www.gnu.org/licenses/>
 */
#include "hw.h"
#include "sim65.h"
#include <minirom.h>
#include <minirom_lbl.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char *prog_name;
static FILE *trace_file;

static void print_help(void)
{
    fprintf(stderr, "Usage: %s [options] <firmware.bin>\n"
                    "Options:\n"
                    " -d       : Print debug messages to standard error\n"
                    " -e <lvl> : Sets the error level to 'none', 'mem' or 'full'\n"
                    " -h       : Show this help\n"
                    " -l <file>: Loads label file, used in simulation trace\n"
                    " -p <file>: Store profile information into file\n"
                    " -r <file>: Load file at $FF00 instead of default mini-rom.\n"
                    " -t <file>: Store simulation trace into file\n",
            prog_name);
}

static void print_error(const char *text)
{
    if (text)
        fprintf(stderr, "%s: %s\n", prog_name, text);
    fprintf(stderr,"%s: Try '-h' for help.\n", prog_name);
    exit(1);
}

static void exit_error(const char *text)
{
    fprintf(stderr, "%s: %s.\n", prog_name, text);
    exit(1);
}

static void store_prof(const char *fname, sim65 s)
{
    FILE *f = fopen(fname, "w");
    if (!f)
    {
        perror(fname);
        exit_error("can't open profile.");
    }
    struct sim65_profile pdata = sim65_get_profile_info(s);
    char buf[256];
    for (unsigned i=0; i<65536; i++)
        if (pdata.exe_count[i])
        {
            fprintf(f, "%9d %04X %s", pdata.exe_count[i], i, sim65_disassemble(s, buf, i));
            if (pdata.branch_taken[i])
                fprintf(f, " (%d times taken)", pdata.branch_taken[i]);
            fputc('\n', f);
        }
    // Summary at end
    unsigned ti  = pdata.total.instructions;
    unsigned tb  = pdata.total.branch_skip + pdata.total.branch_taken;
    fprintf(f, "--------- Total Instructions:    %9d\n"
               "--------- Total Branches:        %9d (%.1f%% of instructions)\n"
               "--------- Total Branches Taken:  %9d (%.1f%% of branches)\n"
               "--------- Branches cross-page:   %9d (%.1f%% of taken branches)\n"
               "--------- Absolute X cross-page: %9d\n"
               "--------- Absolute Y cross-page: %9d\n"
               "--------- Indirect Y cross-page: %9d\n",
               ti, tb, 100.0 * tb / ti,
               pdata.total.branch_taken, 100.0 * pdata.total.branch_taken / tb,
               pdata.total.branch_extra, 100.0 * pdata.total.branch_extra / pdata.total.branch_taken,
               pdata.total.extra_abs_x, pdata.total.extra_abs_y, pdata.total.extra_ind_y );

    fclose(f);
}

static void set_trace_file(const char *fname, sim65 s)
{
    trace_file = fopen(fname, "w");
    if (!trace_file)
    {
        perror(fname);
        exit_error("can't open trace file.");
    }
    sim65_set_trace_file(s, trace_file);
}

static int rom_load(const char *fname, sim65 s)
{
    int c, addr = 0xFF00;
    FILE *f = fopen(fname, "rb");
    if (!f)
        exit_error("can't open ROM file");

    // Load 256 byte ROM
    while (EOF != (c = getc(f)))
    {
        unsigned char data = c;
        if( addr >= 0x10000 )
            exit_error("ROM file too big");
        sim65_add_data_rom(s, addr++, &data, 1);
    }
    fclose(f);

    if( addr != 0x10000 )
        exit_error("ROM file too short");
    return 0;
}

int main(int argc, char **argv)
{
    sim65 s;
    int opt;
    const char *rom = 0;
    const char *lblname = 0, *profname = 0;

    prog_name = argv[0];
    s = sim65_new();
    if (!s)
        exit_error("internal error");

    while ((opt = getopt(argc, argv, "t:dhl:e:p:")) != -1)
    {
        switch (opt)
        {
            case 't': // trace
                sim65_set_debug(s, sim65_debug_trace);
                set_trace_file(optarg, s);
                break;
            case 'd': // debug
                sim65_set_debug(s, sim65_debug_messages);
                break;
            case 'e': // error level
                if (!strcmp(optarg, "n") || !strcmp(optarg, "none"))
                    sim65_set_error_level(s, sim65_errlvl_none);
                else if (!strcmp(optarg, "f") || !strcmp(optarg, "full"))
                    sim65_set_error_level(s, sim65_errlvl_full);
                else if (!strcmp(optarg, "m") || !strcmp(optarg, "mem"))
                    sim65_set_error_level(s, sim65_errlvl_memory);
                else
                    print_error("invalid error level");
                break;
            case 'h': // help
                print_help();
                return 0;
            case 'r': // rom file
                rom = strdup(optarg);
                break;
            case 'l': // label file
                lblname = optarg;
                break;
            case 'p': // profile
                profname = optarg;
                break;
            default:
                print_error(0);
        }
    }

    if (optind >= argc)
        print_error("missing filename");
    else if (optind + 1 != argc)
        print_error("only one filename allowed");
    const char *fname = argv[optind];

    // Load labels file
    if (lblname)
        sim65_lbl_load(s, lblname);

    // Initialize hardware and loads firmware
    if (hw_init(s, fname) == sim65_err_user)
        exit_error("error reading firmware file");

    // Set profile info
    if (profname)
        sim65_set_profiling(s, 1);

    // Read ROM file
    if( rom )
        rom_load(rom, s);
    else
    {
        // Adds internal ROM
        if( ___build_minirom_bin_len != 256 )
            exit_error("internal error: minirom.bin too short");
        sim65_add_data_rom(s, 0xFF00, ___build_minirom_bin, 256);
        // and labels
        for(int i=0; minirom_lbl[i].lbl; i++)
            sim65_lbl_add(s, minirom_lbl[i].addr, minirom_lbl[i].lbl);
    }

    // Runs simulator from RESET pointer
    unsigned reset = sim65_get_byte(s, 0xFFFC) + (sim65_get_byte(s, 0xFFFD) << 8);
    enum sim65_error e = sim65_run(s, 0, reset);
    if (e)
        // Prints error message
        sim65_eprintf(s, "simulator returned %s at address %04x.",
                      sim65_error_str(s, e), sim65_error_addr(s));
    sim65_dprintf(s, "Total cycles: %ld", sim65_get_cycles(s));
    if (profname)
        store_prof(profname, s);
    sim65_free(s);
    if (trace_file)
        fclose(trace_file);
    return 0;
}
