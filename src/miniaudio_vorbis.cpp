/*
miniaudio_vorbis.cpp - Implementation of Vorbis/OGG decoder backend for miniaudio

This implements a custom decoding backend for miniaudio that uses stb_vorbis
for OGG Vorbis file decoding.
*/

#include "miniaudio_vorbis.h"

#include "miniaudio.h"

// Include stb_vorbis implementation
#undef STB_VORBIS_HEADER_ONLY
#include "stb_vorbis.c"

// Data source callbacks
static ma_result ma_stbvorbis_ds_read(ma_data_source* pDataSource, void* pFramesOut, ma_uint64 frameCount,
                                      ma_uint64* pFramesRead)
{
    return ma_stbvorbis_read_pcm_frames((ma_stbvorbis*)pDataSource, pFramesOut, frameCount, pFramesRead);
}

static ma_result ma_stbvorbis_ds_seek(ma_data_source* pDataSource, ma_uint64 frameIndex)
{
    return ma_stbvorbis_seek_to_pcm_frame((ma_stbvorbis*)pDataSource, frameIndex);
}

static ma_result ma_stbvorbis_ds_get_data_format(ma_data_source* pDataSource, ma_format* pFormat, ma_uint32* pChannels,
                                                 ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap)
{
    return ma_stbvorbis_get_data_format((ma_stbvorbis*)pDataSource, pFormat, pChannels, pSampleRate, pChannelMap,
                                        channelMapCap);
}

static ma_result ma_stbvorbis_ds_get_cursor(ma_data_source* pDataSource, ma_uint64* pCursor)
{
    return ma_stbvorbis_get_cursor_in_pcm_frames((ma_stbvorbis*)pDataSource, pCursor);
}

static ma_result ma_stbvorbis_ds_get_length(ma_data_source* pDataSource, ma_uint64* pLength)
{
    return ma_stbvorbis_get_length_in_pcm_frames((ma_stbvorbis*)pDataSource, pLength);
}

static ma_data_source_vtable g_ma_stbvorbis_ds_vtable = {
    ma_stbvorbis_ds_read,
    ma_stbvorbis_ds_seek,
    ma_stbvorbis_ds_get_data_format,
    ma_stbvorbis_ds_get_cursor,
    ma_stbvorbis_ds_get_length,
    NULL, // onSetLooping
    0     // flags
};

MA_API ma_result ma_stbvorbis_init_file(const char* pFilePath, const ma_decoding_backend_config* pConfig,
                                        const ma_allocation_callbacks* pAllocationCallbacks, ma_stbvorbis* pVorbis)
{
    (void)pConfig;
    (void)pAllocationCallbacks;

    if (pVorbis == NULL) {
        return MA_INVALID_ARGS;
    }

    memset(pVorbis, 0, sizeof(*pVorbis));

    int error = 0;
    pVorbis->vorbis = stb_vorbis_open_filename(pFilePath, &error, NULL);
    if (pVorbis->vorbis == NULL) {
        return MA_ERROR;
    }

    stb_vorbis_info info = stb_vorbis_get_info(pVorbis->vorbis);
    pVorbis->format = ma_format_f32; // stb_vorbis outputs float samples
    pVorbis->channels = (ma_uint32)info.channels;
    pVorbis->sampleRate = (ma_uint32)info.sample_rate;
    pVorbis->cursor = 0;

    ma_data_source_config baseConfig = ma_data_source_config_init();
    baseConfig.vtable = &g_ma_stbvorbis_ds_vtable;

    ma_result result = ma_data_source_init(&baseConfig, &pVorbis->base);
    if (result != MA_SUCCESS) {
        stb_vorbis_close(pVorbis->vorbis);
        return result;
    }

    return MA_SUCCESS;
}

MA_API void ma_stbvorbis_uninit(ma_stbvorbis* pVorbis, const ma_allocation_callbacks* pAllocationCallbacks)
{
    (void)pAllocationCallbacks;

    if (pVorbis == NULL) {
        return;
    }

    if (pVorbis->vorbis != NULL) {
        stb_vorbis_close(pVorbis->vorbis);
        pVorbis->vorbis = NULL;
    }

    ma_data_source_uninit(&pVorbis->base);
}

MA_API ma_result ma_stbvorbis_read_pcm_frames(ma_stbvorbis* pVorbis, void* pFramesOut, ma_uint64 frameCount,
                                              ma_uint64* pFramesRead)
{
    if (pVorbis == NULL || pVorbis->vorbis == NULL) {
        return MA_INVALID_ARGS;
    }

    if (pFramesRead != NULL) {
        *pFramesRead = 0;
    }

    if (frameCount == 0) {
        return MA_SUCCESS;
    }

    // stb_vorbis_get_samples_float_interleaved returns number of samples per channel (i.e., frames)
    int framesRead = stb_vorbis_get_samples_float_interleaved(
        pVorbis->vorbis, (int)pVorbis->channels, (float*)pFramesOut, (int)(frameCount * pVorbis->channels));

    pVorbis->cursor += (ma_uint64)framesRead;

    if (pFramesRead != NULL) {
        *pFramesRead = (ma_uint64)framesRead;
    }

    if (framesRead == 0) {
        return MA_AT_END;
    }

    return MA_SUCCESS;
}

MA_API ma_result ma_stbvorbis_seek_to_pcm_frame(ma_stbvorbis* pVorbis, ma_uint64 frameIndex)
{
    if (pVorbis == NULL || pVorbis->vorbis == NULL) {
        return MA_INVALID_ARGS;
    }

    int result = stb_vorbis_seek(pVorbis->vorbis, (unsigned int)frameIndex);
    if (result == 0) {
        return MA_ERROR;
    }

    pVorbis->cursor = frameIndex;
    return MA_SUCCESS;
}

MA_API ma_result ma_stbvorbis_get_data_format(ma_stbvorbis* pVorbis, ma_format* pFormat, ma_uint32* pChannels,
                                              ma_uint32* pSampleRate, ma_channel* pChannelMap, size_t channelMapCap)
{
    if (pVorbis == NULL) {
        return MA_INVALID_ARGS;
    }

    if (pFormat != NULL) {
        *pFormat = pVorbis->format;
    }
    if (pChannels != NULL) {
        *pChannels = pVorbis->channels;
    }
    if (pSampleRate != NULL) {
        *pSampleRate = pVorbis->sampleRate;
    }
    if (pChannelMap != NULL) {
        ma_channel_map_init_standard(ma_standard_channel_map_default, pChannelMap, channelMapCap, pVorbis->channels);
    }

    return MA_SUCCESS;
}

MA_API ma_result ma_stbvorbis_get_cursor_in_pcm_frames(ma_stbvorbis* pVorbis, ma_uint64* pCursor)
{
    if (pVorbis == NULL || pCursor == NULL) {
        return MA_INVALID_ARGS;
    }

    *pCursor = pVorbis->cursor;
    return MA_SUCCESS;
}

MA_API ma_result ma_stbvorbis_get_length_in_pcm_frames(ma_stbvorbis* pVorbis, ma_uint64* pLength)
{
    if (pVorbis == NULL || pVorbis->vorbis == NULL || pLength == NULL) {
        return MA_INVALID_ARGS;
    }

    unsigned int lengthInSamples = stb_vorbis_stream_length_in_samples(pVorbis->vorbis);
    *pLength = (ma_uint64)lengthInSamples;

    return MA_SUCCESS;
}

// ============================================================
// Decoding backend vtable implementation for ma_decoder
// ============================================================

static ma_result ma_decoding_backend_init__stbvorbis(void* pUserData, ma_read_proc onRead, ma_seek_proc onSeek,
                                                     ma_tell_proc onTell, void* pReadSeekTellUserData,
                                                     const ma_decoding_backend_config* pConfig,
                                                     const ma_allocation_callbacks* pAllocationCallbacks,
                                                     ma_data_source** ppBackend)
{
    (void)pUserData;
    (void)onRead;
    (void)onSeek;
    (void)onTell;
    (void)pReadSeekTellUserData;
    (void)pConfig;
    (void)pAllocationCallbacks;
    (void)ppBackend;

    // We only support file-based initialization for now
    return MA_NOT_IMPLEMENTED;
}

static ma_result ma_decoding_backend_init_file__stbvorbis(void* pUserData, const char* pFilePath,
                                                          const ma_decoding_backend_config* pConfig,
                                                          const ma_allocation_callbacks* pAllocationCallbacks,
                                                          ma_data_source** ppBackend)
{
    (void)pUserData;

    ma_stbvorbis* pVorbis = (ma_stbvorbis*)ma_malloc(sizeof(ma_stbvorbis), pAllocationCallbacks);
    if (pVorbis == NULL) {
        return MA_OUT_OF_MEMORY;
    }

    ma_result result = ma_stbvorbis_init_file(pFilePath, pConfig, pAllocationCallbacks, pVorbis);
    if (result != MA_SUCCESS) {
        ma_free(pVorbis, pAllocationCallbacks);
        return result;
    }

    *ppBackend = (ma_data_source*)pVorbis;
    return MA_SUCCESS;
}

static void ma_decoding_backend_uninit__stbvorbis(void* pUserData, ma_data_source* pBackend,
                                                  const ma_allocation_callbacks* pAllocationCallbacks)
{
    (void)pUserData;

    ma_stbvorbis* pVorbis = (ma_stbvorbis*)pBackend;
    ma_stbvorbis_uninit(pVorbis, pAllocationCallbacks);
    ma_free(pVorbis, pAllocationCallbacks);
}

ma_decoding_backend_vtable g_ma_decoding_backend_vtable_stbvorbis = {ma_decoding_backend_init__stbvorbis,
                                                                     ma_decoding_backend_init_file__stbvorbis,
                                                                     NULL, // init_file_w
                                                                     NULL, // init_memory
                                                                     ma_decoding_backend_uninit__stbvorbis};
