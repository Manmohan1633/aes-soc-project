/*
 ============================================================================
 Name        : main.c
 Author      : Manmohan Singh
 Version     :
 Copyright   : Your copyright notice
 Description : Hello World in C
 ============================================================================
 */


/*
 *
 * Print a greeting message on standard output and exit.
 *
 * On embedded platforms this might require semi-hosting or similar.
 *
 * For example, for toolchains derived from GNU Tools for Embedded,
 * to enable semi-hosting, the following was added to the linker:
 *
 * `--specs=rdimon.specs -Wl,--start-group -lgcc -lc -lc -lm -lrdimon -Wl,--end-group`
 *
 * Adjust it for other toolchains.
 *
 * If functionality is not required, to only pass the build, use
 * `--specs=nosys.specs`.
 *
 */

#include <stdint.h>
#include <string.h>

// --- Hardware Memory Map ---
#define AES_BASE      ((uint32_t)0x90000000) // Adjust if TARGEXP0 base differs
#define REG32(off)    (*(volatile uint32_t*)(AES_BASE + (off)))

#define CTRL_REG      REG32(0x00)
#define STATUS_REG    REG32(0x04)
#define DATA_IN_BASE  (AES_BASE + 0x08)
#define KEY_BASE      (AES_BASE + 0x18)
#define DATA_OUT_BASE (AES_BASE + 0x38)

// --- Bitmasks ---
#define CTRL_START    (1 << 0)
#define CTRL_MODE_DEC (1 << 1)
#define CTRL_KEYLOAD  (1 << 2)
#define STAT_DONE     (1 << 1)
#define STAT_KEYRDY   (1 << 2)

// --- Bare-Metal Gowin UART0 Driver ---
#define UART0_BASE   0x40004000
#define UART0_DATA   (*(volatile uint32_t*)(UART0_BASE + 0x00))
#define UART0_STATE  (*(volatile uint32_t*)(UART0_BASE + 0x04))
#define UART0_CTRL   (*(volatile uint32_t*)(UART0_BASE + 0x08))
#define UART0_BAUD   (*(volatile uint32_t*)(UART0_BASE + 0x10))

void UART_Init(void) {
    // 50 MHz System Clock / 115200 Baud Rate = 434
    UART0_BAUD = 434;
    UART0_CTRL = 0x03; // Enable TX (Bit 0) and RX (Bit 1)
}

void UART_SendChar(char c) {
    while(UART0_STATE & 1); // Wait while TX buffer is full
    UART0_DATA = c;
}

char UART_ReceiveChar(void) {
    while(!(UART0_STATE & 2)); // Wait until RX buffer has data
    return (char)(UART0_DATA & 0xFF);
}

void print_str(const char* str) {
    while(*str) UART_SendChar(*str++);
}

void print_hex(uint8_t val) {
    const char hex[] = "0123456789ABCDEF";
    UART_SendChar(hex[val >> 4]);
    UART_SendChar(hex[val & 0x0F]);
}

// --- Hardware Control ---
void load_key(const uint8_t* key32) {
    for(int i=0; i<8; i++) {
        uint32_t word = (key32[i*4]<<24) | (key32[i*4+1]<<16) | (key32[i*4+2]<<8) | key32[i*4+3];
        (*(volatile uint32_t*)(KEY_BASE + i*4)) = word;
    }
    CTRL_REG = CTRL_KEYLOAD;
    while (!(STATUS_REG & STAT_KEYRDY)); // Wait for Key Schedule
}

void process_block(const uint8_t* in_block, uint8_t* out_block, int decrypt) {
    for(int i=0; i<4; i++) {
        uint32_t word = (in_block[i*4]<<24) | (in_block[i*4+1]<<16) | (in_block[i*4+2]<<8) | in_block[i*4+3];
        (*(volatile uint32_t*)(DATA_IN_BASE + i*4)) = word;
    }

    CTRL_REG = CTRL_START | (decrypt ? CTRL_MODE_DEC : 0);
    while (!(STATUS_REG & STAT_DONE)); // Wait for AES Core

    for(int i=0; i<4; i++) {
        uint32_t word = (*(volatile uint32_t*)(DATA_OUT_BASE + i*4));
        out_block[i*4]   = (word >> 24) & 0xFF;
        out_block[i*4+1] = (word >> 16) & 0xFF;
        out_block[i*4+2] = (word >> 8)  & 0xFF;
        out_block[i*4+3] =  word        & 0xFF;
    }
}

// --- Main Application ---
#define MAX_LEN 256
uint8_t input_buf[MAX_LEN];
uint8_t cipher_buf[MAX_LEN + 16];
uint8_t decrypt_buf[MAX_LEN + 16];

int main(void) {
    // SystemInit(); // Ensure Gowin startup code initializes clocks/UART
	UART_Init(); // Turn on the UART hardware and set baud to 115200
    uint8_t demo_key[32] = {
        0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x07,
        0x08,0x09,0x0A,0x0B,0x0C,0x0D,0x0E,0x0F,
        0x10,0x11,0x12,0x13,0x14,0x15,0x16,0x17,
        0x18,0x19,0x1A,0x1B,0x1C,0x1D,0x1E,0x1F
    };

    print_str("\r\n--- SOC AES-256 Hardware Accelerator ---\r\n");
    load_key(demo_key);
    print_str("[+] Hardware Key Loaded.\r\n");

    while(1) {
        print_str("\r\nEnter string to encrypt: ");
        int len = 0;

        // Read dynamic ASCII input
        while(len < MAX_LEN - 1) {
            char c = UART_ReceiveChar();
            if(c == '\r' || c == '\n') break;
            UART_SendChar(c); // Echo character back to terminal
            input_buf[len++] = c;
        }
        input_buf[len] = '\0';
        print_str("\r\n");

        // PKCS#7 Padding logic
        int pad_len = 16 - (len % 16);
        int total_len = len + pad_len;
        for(int i = 0; i < pad_len; i++) {
            input_buf[len + i] = pad_len;
        }

        // Encrypt in hardware
        print_str("[+] Encrypting...\r\nCiphertext (Hex): ");
        for(int i = 0; i < total_len; i += 16) {
            process_block(&input_buf[i], &cipher_buf[i], 0);
            for(int j=0; j<16; j++) print_hex(cipher_buf[i+j]);
        }
        print_str("\r\n");

        // Decrypt in hardware
        print_str("[+] Decrypting in hardware...\r\nRecovered String: ");
        for(int i = 0; i < total_len; i += 16) {
            process_block(&cipher_buf[i], &decrypt_buf[i], 1);
        }

        // Strip padding and print
        int pad_val = decrypt_buf[total_len - 1];
        int valid_len = total_len - pad_val;
        decrypt_buf[valid_len] = '\0';

        print_str((char*)decrypt_buf);
        print_str("\r\n\r\n");
    }
}
