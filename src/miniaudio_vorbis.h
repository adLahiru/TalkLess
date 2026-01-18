/*
miniaudio_vorbis.h - Vorbis/OGG decoder backend for miniaudio using stb_vorbis

Usage:
1. Include this header after miniaudio.h
2. Add stb_vorbis.c to your project
3. Use ma_stbvorbis_init_file() to create a Vorbis data source
4. Use it with ma_decoder or directly

This implementation is based on miniaudio's custom data source API.
*/

#ifndef MINIAUDIO_VORBIS_H
#define MINIAUDIO_VORBIS_H

#include "miniaudio.h"

#ifdef __cplusplus
extern "C" {
#endif

// Forward declaration from stb_vorbis
typedef struct stb_vorbis stb_vorbis;

// stb_vorbis data source structure
typedef struct
{
    ma_data_source_base base;
    stb_vorbis* vorbis;
    ma_format format;
    ma_uint32 channels;
    ma_uint32 sampleRate;
    ma_uint64 cursor;
} ma_stbvorbis;

MA_API ma_result ma_stbvorbis_init_file(const char* pFilePath, const ma_decoding_backend_config* pConfig,
                                        const ma_allocation_callbacks* pAllocationCallbacks, ma_stbvorbis* pVorbis);
MA_API void ma_stbvorbis_uninit(ma_stbvorbis* pVorbis, const ma_allocation_callbacks* pAllocationCallbacks);
MA_API ma_result ma_stbvorbis_read_pcm_frames(ma_stbvorbis* pVorbis, void* pFramesOut, ma_uint64 frameCount,
                                              ma_uint64* pFramesRead);
MA_API ma_result ma_stbvorbis_seek_to_pcm_frame(ma_stbvorbis* pVorbis, ma_uint64 frameIndex);
MA_API ma_result ma_stbvorbis_get_data_format(ma_stbvorbis* pVorbis, ma_format* pFormat, ma_uint32* pChannels,
                                              ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap);
MA_API ma_result ma_stbvorbis_get_cursor_in_pcm_frames(ma_stbvorbis* pVorbis, ma_uint64* pCursor);
MA_API ma_result ma_stbvorbis_get_length_in_pcm_frames(ma_stbvorbis* pVorbis, ma_uint64* pLength);

// Decoding backend vtable for miniaudio decoder
extern ma_decoding_backend_vtable g_ma_decoding_backend_vtable_stbvorbis;

#ifdef __cplusplus
}
#endif

#endif // MINIAUDIO_VORBIS_H
