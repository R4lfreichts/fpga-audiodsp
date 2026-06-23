#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#include "xparameters.h"
#include "xaxidma.h"
#include "xgpio.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_types.h"
#include "sleep.h"

extern const unsigned char _binary_endoftime_audio_wav_start[];
extern const unsigned char _binary_endoftime_audio_wav_end[];

#ifndef DMA_BASEADDR
#ifdef XPAR_XAXIDMA_0_BASEADDR
#define DMA_BASEADDR XPAR_XAXIDMA_0_BASEADDR
#elif defined(XPAR_AXI_DMA_0_BASEADDR)
#define DMA_BASEADDR XPAR_AXI_DMA_0_BASEADDR
#else
#error "No AXI DMA base address macro found in xparameters.h"
#endif
#endif

#ifndef SDT

#ifndef GPIO_DEVICE_ID
#ifdef XPAR_XGPIO_0_DEVICE_ID
#define GPIO_DEVICE_ID XPAR_XGPIO_0_DEVICE_ID
#elif defined(XPAR_AXI_GPIO_0_DEVICE_ID)
#define GPIO_DEVICE_ID XPAR_AXI_GPIO_0_DEVICE_ID
#else
#error "No AXI GPIO device ID macro found in xparameters.h"
#endif
#endif

#else

#ifndef GPIO_BASEADDR
#ifdef XPAR_XGPIO_0_BASEADDR
#define GPIO_BASEADDR XPAR_XGPIO_0_BASEADDR
#elif defined(XPAR_AXI_GPIO_0_BASEADDR)
#define GPIO_BASEADDR XPAR_AXI_GPIO_0_BASEADDR
#else
#error "No AXI GPIO base address macro found in xparameters.h"
#endif
#endif

#endif

#define SAMPLE_RATE_HZ       48000U
#define CHUNK_FRAMES         256U
#define WAV_BYTES_PER_FRAME  6U
#define DMA_TIMEOUT_CYCLES   100000000U

#define BUTTON_CHANNEL       1U
#define BUTTON_LEFT_MASK     0x02U
#define BUTTON_RIGHT_MASK    0x01U

static XAxiDma AxiDma;
static XGpio ButtonsGpio;

/* One 64-bit AXIS word per stereo frame:
 * bits [31:0]  = left  sample, sign-extended from 24-bit
 * bits [63:32] = right sample, sign-extended from 24-bit
 */
static uint64_t play_buf[CHUNK_FRAMES] __attribute__((aligned(64)));

static uint16_t rd16(const unsigned char *p)
{
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t rd32(const unsigned char *p)
{
    return (uint32_t)p[0]
         | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[3] << 24);
}

static int32_t read_s24le(const unsigned char *p)
{
    int32_t v = ((int32_t)p[0])
              | ((int32_t)p[1] << 8)
              | ((int32_t)p[2] << 16);

    if (v & 0x00800000) {
        v |= 0xFF000000;
    }

    return v;
}

static int init_dma(void)
{
    XAxiDma_Config *cfg_ptr;
    int status;

    cfg_ptr = XAxiDma_LookupConfig(DMA_BASEADDR);
    if (cfg_ptr == NULL) {
        printf("DMA config not found\r\n");
        return XST_FAILURE;
    }

    status = XAxiDma_CfgInitialize(&AxiDma, cfg_ptr);
    if (status != XST_SUCCESS) {
        printf("DMA init failed: %d\r\n", status);
        return status;
    }

    if (XAxiDma_HasSg(&AxiDma)) {
        printf("DMA is in SG mode, but simple mode is expected\r\n"); #SG = scather&gather
        return XST_FAILURE;
    }

    return XST_SUCCESS;
}

static int init_buttons(void)
{
    int status;

#ifndef SDT
    status = XGpio_Initialize(&ButtonsGpio, GPIO_DEVICE_ID);
    if (status != XST_SUCCESS) {
        printf("GPIO init failed: %d\r\n", status);
        return status;
    }
#else
    XGpio_Config *cfg_ptr;

    cfg_ptr = XGpio_LookupConfig(GPIO_BASEADDR);
    if (cfg_ptr == NULL) {
        printf("GPIO config not found\r\n");
        return XST_FAILURE;
    }

    status = XGpio_CfgInitialize(&ButtonsGpio, cfg_ptr, cfg_ptr->BaseAddress);
    if (status != XST_SUCCESS) {
        printf("GPIO init failed: %d\r\n", status);
        return status;
    }
#endif

    XGpio_SetDataDirection(&ButtonsGpio, BUTTON_CHANNEL, 0xFFU);
    return XST_SUCCESS;
}

static uint32_t read_buttons(void)
{
    return XGpio_DiscreteRead(&ButtonsGpio, BUTTON_CHANNEL);
}

int main(void)
{
    const unsigned char *wav = _binary_endoftime_audio_wav_start;
    const size_t wav_len =
        (size_t)(_binary_endoftime_audio_wav_end - _binary_endoftime_audio_wav_start);

    size_t pos = 12;
    uint16_t audio_format = 0;
    uint16_t num_channels = 0;
    uint32_t sample_rate = 0;
    uint16_t bits_per_sample = 0;
    uint16_t subformat_tag = 0;
    uint32_t data_size = 0;
    size_t data_offset = 0;
    uint32_t available_frames;
    uint32_t frame_offset = 0;
    uint32_t chunk_count = 0;
    uint32_t prev_buttons = 0;
    int paused = 1;
    int status;

    printf("WAV size: %u bytes\r\n", (unsigned int)wav_len);

    if (wav_len < 44) {
        printf("Error: file too small\r\n");
        while (1) { }
    }

    if (!(wav[0] == 'R' && wav[1] == 'I' && wav[2] == 'F' && wav[3] == 'F')) {
        printf("Error: no RIFF\r\n");
        while (1) { }
    }

    if (!(wav[8] == 'W' && wav[9] == 'A' && wav[10] == 'V' && wav[11] == 'E')) {
        printf("Error: no WAVE\r\n");
        while (1) { }
    }

    while (pos + 8 <= wav_len) {
        const unsigned char *chunk = &wav[pos];
        uint32_t chunk_size = rd32(&wav[pos + 4]);
        size_t next_pos = pos + 8 + chunk_size;

        if (next_pos > wav_len) {
            printf("Error: invalid chunk\r\n");
            while (1) { }
        }

        if (chunk[0] == 'f' && chunk[1] == 'm' && chunk[2] == 't' && chunk[3] == ' ') {
            if (chunk_size < 16) {
                printf("Error: fmt chunk too small\r\n");
                while (1) { }
            }

            audio_format    = rd16(&wav[pos + 8]);
            num_channels    = rd16(&wav[pos + 10]);
            sample_rate     = rd32(&wav[pos + 12]);
            bits_per_sample = rd16(&wav[pos + 22]);

            if (audio_format == 65534 && chunk_size >= 40) {
                subformat_tag = rd16(&wav[pos + 32]);
            }
        } else if (chunk[0] == 'd' && chunk[1] == 'a' && chunk[2] == 't' && chunk[3] == 'a') {
            data_size = chunk_size;
            data_offset = pos + 8;
            break;
        }

        pos = next_pos + (chunk_size & 1u);
    }

    printf("audio_format   = %u\r\n", audio_format);
    printf("subformat_tag  = %u\r\n", subformat_tag);
    printf("num_channels   = %u\r\n", num_channels);
    printf("sample_rate    = %u\r\n", (unsigned int)sample_rate);
    printf("bits_per_smpl  = %u\r\n", bits_per_sample);
    printf("data_offset    = %u\r\n", (unsigned int)data_offset);
    printf("data_size      = %u\r\n", (unsigned int)data_size);

    if (!(audio_format == 1 || (audio_format == 65534 && subformat_tag == 1))) {
        printf("Unsupported WAV format\r\n");
        while (1) { }
    }

    if (num_channels != 2) {
        printf("Unsupported channel count\r\n");
        while (1) { }
    }

    if (sample_rate != SAMPLE_RATE_HZ) {
        printf("Unsupported sample rate\r\n");
        while (1) { }
    }

    if (bits_per_sample != 24) {
        printf("Unsupported bit depth\r\n");
        while (1) { }
    }

    status = init_dma();
    if (status != XST_SUCCESS) {
        while (1) { }
    }

    status = init_buttons();
    if (status != XST_SUCCESS) {
        while (1) { }
    }

    available_frames = data_size / WAV_BYTES_PER_FRAME;

    printf("Ready. Right button = play/pause, left button = reset\r\n");
    printf("Total playback length: %u frames (~%u seconds)\r\n",
           (unsigned int)available_frames,
           (unsigned int)(available_frames / SAMPLE_RATE_HZ));

    while (1) {
        uint32_t buttons = read_buttons();
        uint32_t rising_edges = buttons & (~prev_buttons);

        if (rising_edges != 0U) {
            usleep(20000);
            buttons = read_buttons();
            rising_edges = buttons & (~prev_buttons);
        }

        if ((rising_edges & BUTTON_LEFT_MASK) != 0U) {
            frame_offset = 0;
            chunk_count = 0;
            printf("Reset to start\r\n");
        }

        if ((rising_edges & BUTTON_RIGHT_MASK) != 0U) {
            if (paused) {
                if (frame_offset >= available_frames) {
                    frame_offset = 0;
                    chunk_count = 0;
                }
                paused = 0;
                printf("Playback resumed\r\n");
            } else {
                paused = 1;
                printf("Playback paused\r\n");
            }
        }

        prev_buttons = buttons;

        if (paused) {
            usleep(1000);
            continue;
        }

        if (frame_offset >= available_frames) {
            paused = 1;
            printf("Playback finished\r\n");
            continue;
        }

        {
            const unsigned char *pcm = wav + data_offset;
            uint32_t frames_left = available_frames - frame_offset;
            uint32_t this_chunk = (frames_left > CHUNK_FRAMES) ? CHUNK_FRAMES : frames_left;
            uint32_t i;
            uint32_t timeout = DMA_TIMEOUT_CYCLES;

            for (i = 0; i < this_chunk; ++i) {
                const unsigned char *p =
                    pcm + ((size_t)(frame_offset + i) * WAV_BYTES_PER_FRAME);

                int32_t left  = read_s24le(&p[0]);
                int32_t right = read_s24le(&p[3]);

                play_buf[i] = ((uint64_t)(uint32_t)right << 32)
                            |  (uint32_t)left;
            }

            Xil_DCacheFlushRange((UINTPTR)play_buf, (UINTPTR)(this_chunk * sizeof(uint64_t)));

            status = XAxiDma_SimpleTransfer(
                &AxiDma,
                (UINTPTR)play_buf,
                this_chunk * sizeof(uint64_t),
                XAXIDMA_DMA_TO_DEVICE
            );

            if (status != XST_SUCCESS) {
                printf("DMA transfer failed at frame_offset=%u, chunk=%u, status=%d\r\n",
                       (unsigned int)frame_offset,
                       (unsigned int)this_chunk,
                       status);
                while (1) { }
            }

            while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {
                if (--timeout == 0U) {
                    printf("Timeout waiting for DMA done at frame_offset=%u, chunk=%u\r\n",
                           (unsigned int)frame_offset,
                           (unsigned int)this_chunk);
                    while (1) { }
                }
            }

            frame_offset += this_chunk;
            chunk_count++;

            if ((chunk_count & 0x3FFU) == 0U) {
                printf("Played %u / %u frames\r\n",
                       (unsigned int)frame_offset,
                       (unsigned int)available_frames);
            }
        }
    }

    return 0;
}