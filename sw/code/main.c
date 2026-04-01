#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#include "xparameters.h"
#include "xaxidma.h"
#include "xstatus.h"
#include "xil_cache.h"
#include "xil_types.h"

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

#define SAMPLE_RATE_HZ      48000U
#define SECONDS_TO_PLAY     1U
#define TOTAL_FRAMES_TO_PLAY (SAMPLE_RATE_HZ * SECONDS_TO_PLAY)
#define CHUNK_FRAMES        1U
#define WAV_BYTES_PER_FRAME 6U

static XAxiDma AxiDma;

/* 64-bit stereo frames for PL:
 * bits [31:0]  = left sample  (sign-extended to 32 bit)
 * bits [63:32] = right sample (sign-extended to 32 bit)
 */
static uint64_t play_buf[CHUNK_FRAMES] __attribute__((aligned(64)));

static uint16_t rd16(const unsigned char *p) {
    return (uint16_t)p[0] | ((uint16_t)p[1] << 8);
}

static uint32_t rd32(const unsigned char *p) {
    return (uint32_t)p[0]
         | ((uint32_t)p[1] << 8)
         | ((uint32_t)p[2] << 16)
         | ((uint32_t)p[3] << 24);
}

static int32_t read_s24le(const unsigned char *p) {
    int32_t v = ((int32_t)p[0])
              | ((int32_t)p[1] << 8)
              | ((int32_t)p[2] << 16);

    if (v & 0x00800000) {
        v |= 0xFF000000;  /* sign extension */
    }

    return v;
}

int main(void) {
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

    XAxiDma_Config *CfgPtr;
    int Status;

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

            audio_format = rd16(&wav[pos + 8]);
            num_channels = rd16(&wav[pos + 10]);
            sample_rate = rd32(&wav[pos + 12]);
            bits_per_sample = rd16(&wav[pos + 22]);

            if (audio_format == 65534 && chunk_size >= 40) {
                subformat_tag = rd16(&wav[pos + 32]);  /* PCM subtype -> 1 */
            }
        } else if (chunk[0] == 'd' && chunk[1] == 'a' && chunk[2] == 't' && chunk[3] == 'a') {
            data_size = chunk_size;
            data_offset = pos + 8;
            break;
        }

        pos = next_pos + (chunk_size & 1u);
    }

    printf("audio_format = %u\r\n", audio_format);
    printf("subformat_tag = %u\r\n", subformat_tag);
    printf("num_channels = %u\r\n", num_channels);
    printf("sample_rate = %u\r\n", (unsigned int)sample_rate);
    printf("bits_per_smpl = %u\r\n", bits_per_sample);
    printf("data_offset = %u\r\n", (unsigned int)data_offset);
    printf("data_size = %u\r\n", (unsigned int)data_size);

    if (!(audio_format == 1 || (audio_format == 65534 && subformat_tag == 1))) {
        printf("Unsupported WAV format\r\n");
        while (1) { }
    }

    if (num_channels != 2) {
        printf("Unsupported channel count\r\n");
        while (1) { }
    }

    if (sample_rate != 48000) {
        printf("Unsupported sample rate\r\n");
        while (1) { }
    }

    if (bits_per_sample != 24) {
        printf("Unsupported bit depth\r\n");
        while (1) { }
    }
    {
    const unsigned char *pcm = wav + data_offset;
    uint32_t available_frames = data_size / WAV_BYTES_PER_FRAME;
    uint32_t frames_left = TOTAL_FRAMES_TO_PLAY;
    uint32_t frame_offset = 0;

    if (available_frames < frames_left) {
        frames_left = available_frames;
    }

    printf("Preparing %u frames (~%u seconds)\r\n",
           (unsigned int)frames_left,
           (unsigned int)(frames_left / SAMPLE_RATE_HZ));

    printf("Lookup DMA config...\r\n");
    CfgPtr = XAxiDma_LookupConfig(DMA_BASEADDR);
    if (CfgPtr == NULL) {
        printf("DMA config not found\r\n");
        while (1) { }
    }

    printf("Init DMA...\r\n");
    Status = XAxiDma_CfgInitialize(&AxiDma, CfgPtr);
    if (Status != XST_SUCCESS) {
        printf("DMA init failed: %d\r\n", Status);
        while (1) { }
    }

    printf("Check SG mode...\r\n");
    if (XAxiDma_HasSg(&AxiDma)) {
        printf("DMA is in SG mode, but simple mode is expected\r\n");
        while (1) { }
    }

    printf("Start chunk loop...\r\n");

    while (frames_left > 0) {
        uint32_t this_chunk = (frames_left > CHUNK_FRAMES) ? CHUNK_FRAMES : frames_left;
        uint32_t i;
        uint32_t timeout = 100000000;

        printf("Fill chunk at frame_offset=%u, chunk=%u\r\n",
               (unsigned int)frame_offset,
               (unsigned int)this_chunk);

        for (i = 0; i < this_chunk; ++i) {
            const unsigned char *p =
                pcm + ((size_t)(frame_offset + i) * WAV_BYTES_PER_FRAME);

            int32_t left  = read_s24le(&p[0]);
            int32_t right = read_s24le(&p[3]);

            play_buf[i] = ((uint64_t)(uint32_t)right << 32)
                        |  (uint32_t)left;
        }

        printf("Flush cache...\r\n");
        Xil_DCacheFlushRange((UINTPTR)play_buf, (UINTPTR)(this_chunk * sizeof(uint64_t)));

        printf("Start DMA transfer...\r\n");
        Status = XAxiDma_SimpleTransfer(
            &AxiDma,
            (UINTPTR)play_buf,
            this_chunk * sizeof(uint64_t),
            XAXIDMA_DMA_TO_DEVICE
        );

        if (Status != XST_SUCCESS) {
            printf("DMA transfer failed at frame_offset=%u, chunk=%u, status=%d\r\n",
                   (unsigned int)frame_offset,
                   (unsigned int)this_chunk,
                   Status);
            while (1) { }
        }

        printf("Wait for DMA done...\r\n");
        while (XAxiDma_Busy(&AxiDma, XAXIDMA_DMA_TO_DEVICE)) {
            if (--timeout == 0) {
                printf("Timeout waiting for DMA done at frame_offset=%u\r\n",
                       (unsigned int)frame_offset);
                while (1) { }
            }
        }

        printf("Chunk done\r\n");

        frame_offset += this_chunk;
        frames_left  -= this_chunk;
    }
    printf("Playback finished\r\n");
}

    while (1) { }

    return 0;
}