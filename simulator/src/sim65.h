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
#pragma once

#include <stdint.h>
#include <stdio.h>

typedef struct sim65s *sim65;

/// Debug levels
enum sim65_debug {
    sim65_debug_none = 0,
    sim65_debug_messages = 1,
    sim65_debug_trace = 2
};

/// Errors returned by simulator
enum sim65_error {
    sim65_err_none        = 0,
    sim65_err_exec_undef  = -1,   // 0
    sim65_err_exec_uninit = -2,   // 1
    sim65_err_read_undef  = -3,   // 1
    sim65_err_read_uninit = -4,   // 2
    sim65_err_write_undef = -5,   // 1
    sim65_err_write_rom   = -6,   // 2
    sim65_err_break       = -7,   // 0
    sim65_err_invalid_ins = -8,   // 0
    sim65_err_call_ret    = -9,   // 0
    sim65_err_cycle_limit = -10,  // 0
    sim65_err_user        = -11   // 0
};

/// Error levels - makes simulation return on only certain errors critical most
enum sim65_error_lvl {
    /// Only return on unhandled errors: BRK, invalid instructions, undefined memory execution.
    sim65_errlvl_none = 0,
    /// Also return on most memory errors, ignore write to ROM and read from uninitialized.
    sim65_errlvl_memory = 1,
    /// Return in all errors.
    sim65_errlvl_full = 2,
    /// Default error level
    sim65_errlvl_default = sim65_errlvl_memory
};

/// Structure with profile information
struct sim65_profile {
    /// Array with count of executed instructions at each address, from 0 to 65535.
    const unsigned *exe_count;
    /// Array with count of taken branches from each address, from 0 to 65535.
    const unsigned *branch_taken;
    struct {
        /// Total number of cycles
        unsigned cycles;
        /// Total number of instructions executed
        unsigned instructions;
        /// Total extra cycles per read indirect Y to other page
        unsigned extra_ind_y;
        /// Total extra cycles per read absolute X to other page
        unsigned extra_abs_x;
        /// Total extra cycles per read absolute y to other page
        unsigned extra_abs_y;
        /// Total number of branches skipped
        unsigned branch_skip;
        /// Total number of branches taken
        unsigned branch_taken;
        /// Total extra cycles per branch taken to other page
        unsigned branch_extra;
    } total;
};

/// Creates new simulator state, with no address regions defined.
sim65 sim65_new();
/// Deletes simulator state, freeing all memory.
void sim65_free(sim65 s);
/// Adds an uninitialized RAM region.
void sim65_add_ram(sim65 s, unsigned addr, unsigned len);
/// Adds a zeroed RAM region.
void sim65_add_zeroed_ram(sim65 s, unsigned addr, unsigned len);
/// Adds a RAM region with the given data.
void sim65_add_data_ram(sim65 s, unsigned addr, const unsigned char *data, unsigned len);
/// Adds a ROM region with the given data.
void sim65_add_data_rom(sim65 s, unsigned addr, const unsigned char *data, unsigned len);
/// Sets debug flag to "level".
void sim65_set_debug(sim65 s, enum sim65_debug level);
/// Sets tracing file, instead of stderr..
void sim65_set_trace_file(sim65 s, FILE *f);
/// Sets the error level to "level"
void sim65_set_error_level(sim65 s, enum sim65_error_lvl level);
/// Prints message if debug flag was given debug
int sim65_dprintf(sim65 s, const char *format, ...);
/// Prints error message always
int sim65_eprintf(sim65 s, const char *format, ...);

/// Struct used to pass the register values
struct sim65_reg
{
    uint16_t pc;
    uint8_t a, x, y, p, s;
};

enum sim65_flags {
    SIM65_FLAG_C = 0x01,
    SIM65_FLAG_Z = 0x02,
    SIM65_FLAG_I = 0x04,
    SIM65_FLAG_D = 0x08,
    SIM65_FLAG_B = 0x10,
    SIM65_FLAG_V = 0x40,
    SIM65_FLAG_N = 0x80
};

enum sim65_cb_type
{
    sim65_cb_write = 0,
    sim65_cb_read = -1,
    sim65_cb_exec = -2
};

/** Callback from the simulator.
 * @param s sim65 state.
 * @param regs simulator register values before the instruction.
 * @param addr address of memory causing the callback.
 * @param data type of callback:
 *             sim65_cb_read = read memory
 *             sim65_cb_exec = execute address
 *             other value   = write memory, data is the value to write.
 * @returns the value (0-255) in case of read-callback, or an negative value
 *          from enum sim65_error. */
typedef int (*sim65_callback)(sim65 s, struct sim65_reg *regs, unsigned addr, int data);

/// Adds a callback at the given address of the given type
void sim65_add_callback(sim65 s, unsigned addr, sim65_callback cb, enum sim65_cb_type type);
/// Adds a callback at the given address range of the given type
void sim65_add_callback_range(sim65 s, unsigned addr, unsigned len,
                              sim65_callback cb, enum sim65_cb_type type);

/// Sets or clear a flag in the simulation flag register
void sim65_set_flags(sim65 s, uint8_t flag, uint8_t val);

/** Sets a limit for the number of cycles executed.
 *  Simulation will return with @sim65_err_cycle_limit after this amount of
 *  cycles are executed.
 *  A value of 0 disables the limit. */
void sim65_set_cycle_limit(sim65 s, uint64_t limit);

/// Reads from simulation state.
unsigned sim65_get_byte(sim65 s, unsigned addr);

/// Returns a pointer to simulated memory.
uint8_t *sim65_get_pbyte(sim65 s, unsigned addr);

/// Runs the simulation. Stops at BRK, a callback returning != 0 or execution errors.
/// If regs is NULL, initializes the registers to zero.
enum sim65_error sim65_run(sim65 s, struct sim65_reg *regs, unsigned addr);

/// Calls the simulation.
/// Simulates a call via a JSR to the given address, pushing a (fake) return address
/// to the stack and returning on the matching RTS.
/// If regs is NULL, initializes the registers to zero.
/// @returns 0 if exit through the RTS, non 0 when stops at BRK, a callback
///          returning != 0 or execution errors.
enum sim65_error sim65_call(sim65 s, struct sim65_reg *regs, unsigned addr);

/// Prints the current register values to given file
void sim65_print_reg(sim65 s, FILE *f);

/// Returns memory address of last error
uint16_t sim65_error_addr(sim65 s);

/// Returns string representing error value
const char *sim65_error_str(sim65 s, enum sim65_error e);

/// Load labels from a file, in CC65 format
int sim65_lbl_load(sim65 s, const char *lblname);

/// Adds a single label
void sim65_lbl_add(sim65 s, uint16_t addr, const char *lbl);

/// Returns number of cycles executed
unsigned long sim65_get_cycles(const sim65 s);

/// Activate instruction profiling.
void sim65_set_profiling(sim65 s, int set);

/// Get's profiling information.
/// @returns a sim65_profile struct with the profile data.
struct sim65_profile sim65_get_profile_info(const sim65 s);

/// Returns name of label in given location, or null pointer if not found
const char *sim65_get_label(const sim65 s, uint16_t addr);

/// Disassembles the givenn address to the buffer, length should be > 128.
/// @returns the same buffer passed.
char * sim65_disassemble(const sim65 s, char *buf, uint16_t addr);
