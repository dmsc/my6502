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

#include <fcntl.h>
#include <stdlib.h>
#include <limits.h>
#include <termios.h>
#include <unistd.h>
#include <sys/mman.h>
#include <pthread.h>
#include <string.h>
#include <utime.h>

// TIMER: $FE00 - $FE1F
static int sim_timer(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    int reg = addr & 3;

    static uint16_t count0 = 0;
    static int active = 0;
    static int shot = 0;
    static unsigned next_shot = 0;

    unsigned cycles = sim65_get_cycles(s);

    uint16_t count = active ? (count0 - cycles) : count0;

    if( next_shot && (cycles > next_shot) )
        shot = 1;

    if (data == sim65_cb_read)
    {
        switch( reg )
        {
            case 0:
                return count0 & 0xFF;
            case 1:
                return (count0 >> 8);
            default:
                return shot * 128 + active;
        }
    }
    else
    {
        // Adds 1 if active, because HW misses the decrement.
        count = count + (active?1:0);

        switch( reg )
        {
            case 0:
                count = count + (data & 0xFF);
                break;
            case 1:
                // Adds 1 if active, because HW misses the decrement.
                count = count + ((data & 0xFF) << 8);
                break;
            default:
                shot = !!(data & 0x80);
                active = !!(data & 0x01);
                if (!active)
                    count = 0;
                break;
        }
        if( active )
        {
            count0 = count + cycles;
            next_shot = cycles + count;
        }
        else
        {
            count0 = count;
            next_shot = 0;
        }
//        fprintf(stderr,"TIMER: c=%04X s=%02x cy=%08X nx=%08X\n",
//                count, active + 128*shot, cycles, next_shot);
    }
    return 0;
}

/* UART support routines - set and reset RAW terminal modes */
static void set_raw_term(int raw)
{
    static int term_raw = 0;
    static struct termios oldattr; // Initial terminal state
    if(raw == term_raw)
        return;

    term_raw = raw;
    if(term_raw)
    {
        fprintf(stderr,"Terminal initialized - press CONTROL-C to exit!\n"
                       "-----------------------------------------------\n"
                       "\n");
        struct termios newattr;
        tcgetattr(STDIN_FILENO, &oldattr);
        newattr = oldattr;
        // Set terminal in RAW mode
        cfmakeraw(&newattr);
        // But activate handling of CONTROL-C and CONTROL-Z.
        newattr.c_lflag |= ISIG;
        newattr.c_cc[VMIN] = 0;
        newattr.c_cc[VTIME] = 0;
        tcsetattr(STDIN_FILENO, TCSANOW, &newattr);
    }
    else
    {
        tcsetattr(STDIN_FILENO, TCSAFLUSH, &oldattr);
        printf("\r");
    }
}

static void reset_term(void)
{
    set_raw_term(0);
}

// UART: $FE20 - $FE3F
static int sim_uart(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    // Simulates TX/RX to console
    // UART is simulated at a fixed clock, at 115200 baud, with 12.5875MHz CPU clock,
    // we have TX/RX at 109 cycles per baud, 1090 cycles per word.
    const unsigned div = 1090;

    int reg = addr & 1;

    static unsigned curr_tx = 0;
    static unsigned init = 0;
    static int tx_busy = 0;
    static int next_rx = -1;
    static int rx_ok = 0;


    if( !init )
    {
        // Init stdin
        if( isatty(STDIN_FILENO) )
        {
            // We have a TTY, set terminal properties
            atexit(reset_term);
            set_raw_term(1);
        }
        else
        {
            int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
            fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
        }
        init = 1;
    }

    unsigned cycles = sim65_get_cycles(s);

    int tx_shift = curr_tx && (cycles < curr_tx);
    if( !tx_shift && tx_busy )
    {
        curr_tx += div;
        tx_shift = (cycles < curr_tx);
        tx_busy = 0;
    }

    if ( !rx_ok )
    {
        // Try to read a character
        char ch;
        if( read(STDIN_FILENO, &ch, 1) == 1 )
        {
            next_rx = ch & 0xFF;
            rx_ok = (next_rx >= 0);
            if( ch == 1) // CONTROL-A
                return -1;
        }
    }

    if (data == sim65_cb_read)
    {
        switch( reg )
        {
            case 0:
                return next_rx & 0xFF;
            case 1:
                return tx_busy * 128 + rx_ok * 64;
        }
    }
    else
    {
        switch( reg )
        {
            case 0:
                if( tx_busy )
                    fprintf(stderr, "\nUART: TX overrun, char lost\n");
                // Simply output char
                char c = data & 0xFF;
                write(STDOUT_FILENO, &c, 1);
                // And add to the shift or hold register
                if( !tx_shift )
                    curr_tx = cycles + div;
                else
                    tx_busy = 1;
                break;
            case 1:
                rx_ok = 0;
                break;
        }
    }
    return 0;
}


// LEDDA_IP: $FE40 - $FE5F
static int sim_led(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    // TODO: not simulated yet
    if (data == sim65_cb_read)
        return 0xFF;
    else
        return 0;
}

// VGA thread - updates video image file
struct vga_info {
    uint8_t *mem;
    int terminate;
    uint8_t *pmem;
    unsigned vga_page;
    unsigned hv_mode;
    unsigned pix_height;
    unsigned bitmap_base;
    unsigned color_base;
    unsigned font_base;
    pthread_t thread;
    pthread_mutex_t mutex;
};

enum vga_hv_mode {
    VGA_HMODE_TEXT  = 0,
    VGA_HMODE_HIRES = 1,
    VGA_HMODE_HICLR = 2,
    VGA_HMODE_LORES = 3
};

static void vga_gen_line(uint8_t *buf, struct vga_info *v, unsigned baddr, unsigned line)
{
    static uint8_t palR[16] = {   0,   0,   0,   0, 150, 150, 150, 150, 104, 104, 104, 104, 255, 255, 255, 255};
    static uint8_t palG[16] = {   0,   0, 150, 150,   0,   0, 150, 150, 104, 104, 255, 255, 104, 104, 255, 255};
    static uint8_t palB[16] = {   0, 150,   0, 150,   0, 150,   0, 150, 104, 255, 104, 255, 104, 255, 104, 255};
    // Compose image line depending on mode
    switch( v->hv_mode )
    {
        case VGA_HMODE_TEXT:
        {
            for(int col = 0; col < 80; col ++)
            {
                uint8_t ch = v->mem[(v->bitmap_base + baddr + col) & 0xFFFF];
                uint8_t c = v->mem[(v->color_base + baddr + col) & 0xFFFF];
                uint8_t b = v->mem[((v->font_base + line) * 256 + ch) & 0xFFFF];
                for(int i=0; i<8; i++)
                {
                    *buf++ = (b & 1) ? palR[c&15] : palR[c>>4];
                    *buf++ = (b & 1) ? palG[c&15] : palG[c>>4];
                    *buf++ = (b & 1) ? palB[c&15] : palB[c>>4];
                    b = b >> 1;
                }
            }
            break;
        }
        case VGA_HMODE_HIRES:
        {
            for(int col = 0; col < 80; col ++)
            {
                uint8_t b = v->mem[(v->bitmap_base + baddr + col) & 0xFFFF];
                uint8_t c = v->mem[(v->color_base + baddr + col) & 0xFFFF];
                for(int i=0; i<8; i++)
                {
                    *buf++ = (b & 1) ? palR[c&15] : palR[c>>4];
                    *buf++ = (b & 1) ? palG[c&15] : palG[c>>4];
                    *buf++ = (b & 1) ? palB[c&15] : palB[c>>4];
                    b = b >> 1;
                }
            }
            break;
        }
        case VGA_HMODE_HICLR:
        {
            for(int col = 0; col < 160; col ++)
            {
                uint8_t b = v->mem[(v->bitmap_base + baddr + col) & 0xFFFF];
                *buf++ = palR[b&15];
                *buf++ = palG[b&15];
                *buf++ = palB[b&15];
                *buf++ = palR[b>>4];
                *buf++ = palG[b>>4];
                *buf++ = palB[b>>4];
            }
            break;
        }
        case VGA_HMODE_LORES:
        {
            for(int col = 0; col < 40; col ++)
            {
                uint8_t b = v->mem[(v->bitmap_base + baddr + col) & 0xFFFF];
                uint8_t c = v->mem[(v->color_base + baddr + col) & 0xFFFF];
                for(int i=0; i<8; i++)
                {
                    *buf++ = (b & 1) ? palR[c&15] : palR[c>>4];
                    *buf++ = (b & 1) ? palG[c&15] : palG[c>>4];
                    *buf++ = (b & 1) ? palB[c&15] : palB[c>>4];
                    *buf++ = (b & 1) ? palR[c&15] : palR[c>>4];
                    *buf++ = (b & 1) ? palG[c&15] : palG[c>>4];
                    *buf++ = (b & 1) ? palB[c&15] : palB[c>>4];
                    b = b >> 1;
                }
            }
            break;
        }
    }
}

static void * vga_thread(void *arg)
{
    struct vga_info *v = (struct vga_info *)arg;
    const char *fname = "my6502_sim-vga.ppm";
    const unsigned fsize = 15 * 64 * 1024;

    // Opens and maps external video file
    int fd = open(fname, O_CREAT | O_RDWR, 0660 );
    if( !fd )
    {
        perror(fname);
        fprintf(stderr, "error creating output VGA image file\n");
        exit(1);
    }
    if( fsize != lseek(fd, fsize, SEEK_SET) )
    {
        perror("seek");
        fprintf(stderr, "error creating output VGA image file\n");
        exit(1);
    }
    if( 1 != write(fd, "", 1) )
    {
        perror("write");
        fprintf(stderr, "error creating output VGA image file\n");
        exit(1);
    }
    unsigned char *faddr = mmap(NULL, fsize, PROT_READ | PROT_WRITE,
                                MAP_SHARED, fd, 0);
    if( faddr == MAP_FAILED )
    {
        perror("mmap");
        fprintf(stderr, "error creating output VGA image file\n");
        exit(1);
    }
    const char * fhead = "P6 640 480 255\n";
    memcpy(faddr, fhead, strlen(fhead));
    unsigned char *addr = faddr + strlen(fhead);

    while( 0 == __atomic_load_n( &(v->terminate), __ATOMIC_ACQUIRE) )
    {
        usleep(20000);
        // Lock memory
        pthread_mutex_lock(&v->mutex);
        // Move memory out from CPU
        memcpy(v->mem + (v->vga_page & 7) * 8192, v->pmem, 8192);
        // Unlock memory
        pthread_mutex_unlock(&v->mutex);
        // Generate RGB image
        int lcount = 0, xaddr = 0;
        for(int y=0; y<480; y++)
        {
            vga_gen_line(addr + y * 640 * 3, v, xaddr, lcount);
            if(lcount == v->pix_height)
            {
                lcount = 0;
                if (v->hv_mode == VGA_HMODE_HICLR)
                    xaddr += 160;
                else if (v->hv_mode == VGA_HMODE_HIRES || v->hv_mode == VGA_HMODE_TEXT)
                    xaddr += 80;
                else
                    xaddr += 40;
            }
            else
                lcount ++;

        }
        // Sync RAM to file
        msync(faddr, fsize, MS_ASYNC);
    }

    // Terminate program
    return 0;
}

// VGA: $FE60 - $FE7F
static int sim_vga(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    // VGA state
    static struct vga_info v = {
        .mem = 0,
        .pmem = 0,
        .terminate = 0,
        .vga_page = 0,
        .hv_mode = 0,
        .pix_height = 15,
        .bitmap_base = 0,
        .color_base = 4096,
        .font_base = 32,
        .thread = 0
    };

    // Init VGA
    if (!v.mem)
    {
        v.mem = calloc(65536, 1);
        v.pmem = sim65_get_pbyte(s, 0xD000);
        pthread_mutex_init(&v.mutex, 0);
        if (0 != pthread_create(&(v.thread), 0, vga_thread, &v))
        {
            perror("create vga thread");
            exit(1);
        }
    }

    addr &= 7;      // 3 address bits
    if (data == sim65_cb_read)
        return 0xFF;
    else
    {
        switch (addr)
        {
            case 0:     // VGAPAGE
                {
                    unsigned new_page = data & 7;
                    if( new_page != v.vga_page )
                    {
                        // Lock memory
                        pthread_mutex_lock(&v.mutex);
                        // Move memory out from CPU
                        memcpy(v.mem + (v.vga_page & 7) * 8192, v.pmem, 8192);
                        // Update page
                        v.vga_page = new_page;
                        // Move new page in to CPU
                        memcpy(v.pmem, v.mem + (v.vga_page & 7) * 8192, 8192);
                        // Unlock memory
                        pthread_mutex_unlock(&v.mutex);
                    }
                }
                break;
            case 1:     // VGAMODE
                v.hv_mode = data & 3;
                v.pix_height = (data >> 3) & 31;
                break;
            case 2:     // VGAGBASE_L
                v.bitmap_base = (v.bitmap_base & 0xFF00) | (data & 0xFF);
                break;
            case 3:     // VGAGBASE_H
                v.bitmap_base = (v.bitmap_base & 0xFF) | ((data << 8) & 0xFF00);
                break;
            case 4:     // VGACBASE_L
                v.color_base = (v.color_base & 0xFF00) | (data & 0xFF);
                break;
            case 5:     // VGACBASE_H
                v.color_base = (v.color_base & 0xFF) | ((data << 8) & 0xFF00);
                break;
            case 6:     // VGAFBASE
                v.font_base = data & 0xFF;
                break;
            case 7:     // unused
                break;
        }
    }
    return 0;
}

// SPI: $FE80 - $FE9F
static uint8_t *spi_flash;
#define FLASH_SIZE (2*1024*1024)
static int sim_spi(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    static int gen_cs = 1;
    static int rx_valid = 0;
    static int rx_data = 0;
    static int rx_next = 0;
    static int tx_data = 0;
    static int tx_hold = 0;
    static unsigned nxt_cycle = 0;

    static int spi_state = 0;
    static int spi_cmd  = 0;
    static int spi_addr = 0;

    unsigned cycles = sim65_get_cycles(s);
    if ( (cycles - nxt_cycle) < INT_MAX )
    {
        rx_data = rx_next;
        if( tx_hold )
            nxt_cycle += 16;
        else
            nxt_cycle = cycles + INT_MAX;
        if ( tx_hold )
        {
            // perform read/writes instantly
            rx_next = 0xFF;
            tx_hold = 0;
            rx_valid = !rx_valid;
            if( gen_cs )
            {
                spi_state = -4;
                spi_cmd = tx_data;
                spi_addr = 0;
                rx_valid = 0;
                gen_cs = 0;
                if( spi_cmd != 0x03 )
                    sim65_eprintf(s, "spi: unimplemented command $%02X\n", spi_cmd);
            }
            else
            {
                spi_state ++;
                if( spi_state < 0 )
                    spi_addr = (spi_addr << 8) | tx_data;
                else
                {
                    // TODO: all commands are implemented as READ MEM
                    if( spi_flash )
                        rx_next = spi_flash[spi_addr];
                    spi_addr = (spi_addr + 1) & (FLASH_SIZE-1);
                }
            }
        }
    }


    addr &= 15;         //4 address bits
    if (data == sim65_cb_read)
        switch (addr)
        {
            case 0:
                return (tx_hold << 7) | (rx_valid << 6) | gen_cs;
            case 1:
                return rx_data;
            default:
                return 0xFF;
        }
    else
        switch (addr)
        {
            case 0:
                gen_cs = 1;
                break;
            case 1:
                tx_data = data & 0xFF;
                tx_hold = 1;
                nxt_cycle = cycles + 16;
                if ( (cycles - nxt_cycle) > 32 )
                    nxt_cycle = 1;
                break;
        }

    return 0;
}

static int parity(int n)
{
    int p = n ^ (n >> 1);
    p = p ^ (p >> 2);
    return (p ^ (p >> 4)) & 1;
}

// PS2: $FEA0 - $FEBF
static int sim_ps2(sim65 s, struct sim65_reg *regs, unsigned addr, int data)
{
    static int rx_hold = 0;
    static int rx_keycode = 0;
    static int rx_ascii = 0;
    static int shifts = 0;
    static int code_ext = 0;

    addr = addr & 3;    // 2 bits valid

    // TODO: only simulates the key pressed, ignores timing
    if (data == sim65_cb_read)
    {
        switch(addr)
        {
            case 0:
                {
                    int code_rel = 0;
                    int rx_parity = parity(rx_keycode);
                    return (rx_hold<<7) | (code_rel<<6) | (rx_parity<<5) |
                           (code_ext<<4) | shifts;
                }
            case 1:
                return rx_keycode;
            case 2:
                return 128 | rx_ascii;
            default:
                return 0xFF;
        }
    }
    else
    {
        rx_hold = 0;
        return 0;
    }
}

// Load flash
static void flash_load(const char *fname)
{
    spi_flash = malloc(FLASH_SIZE);
    if( !spi_flash )
    {
        perror("allocate flash");
        exit(1);
    }
    for(int i=0; i<FLASH_SIZE; i++)
        spi_flash[i] = 0xFF;

    FILE *f = fopen(fname, "rb");
    if (!f)
    {
        perror("firmware");
        fprintf(stderr, "can't open firmware file.\n");
        exit(1);
    }

    int c, addr = 128*1024;
    while ((addr < FLASH_SIZE) && (EOF != (c = getc(f))))
    {
        spi_flash[addr] = c;
        addr++;
    }
    fclose(f);
}

// Initialize hardware
enum sim65_error hw_init(sim65 s, const char *fname)
{
    // Load firmware
    flash_load(fname);

    // Adds RAM
    sim65_add_ram(s, 0, 0xFE00);
    sim65_add_zeroed_ram(s, 0xD000, 0x2000);

    // Add hardware callbacks
    sim65_add_callback_range(s, 0xFE00, 0x20, sim_timer, sim65_cb_read);
    sim65_add_callback_range(s, 0xFE00, 0x20, sim_timer, sim65_cb_write);
    sim65_add_callback_range(s, 0xFE20, 0x20, sim_uart, sim65_cb_read);
    sim65_add_callback_range(s, 0xFE20, 0x20, sim_uart, sim65_cb_write);
    sim65_add_callback_range(s, 0xFE40, 0x20, sim_led, sim65_cb_read);
    sim65_add_callback_range(s, 0xFE40, 0x20, sim_led, sim65_cb_write);
    sim65_add_callback_range(s, 0xFE60, 0x20, sim_vga, sim65_cb_read);
    sim65_add_callback_range(s, 0xFE60, 0x20, sim_vga, sim65_cb_write);
    sim65_add_callback_range(s, 0xFE80, 0x20, sim_spi, sim65_cb_read);
    sim65_add_callback_range(s, 0xFE80, 0x20, sim_spi, sim65_cb_write);
    sim65_add_callback_range(s, 0xFEA0, 0x20, sim_ps2, sim65_cb_read);
    sim65_add_callback_range(s, 0xFEA0, 0x20, sim_ps2, sim65_cb_write);
    return 0;
}

