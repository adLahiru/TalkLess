// ffmpeg_decoder.h
// FFmpeg-based audio decoder for formats not supported by miniaudio (e.g., Opus)
#pragma once

#include <cstdint>
#include <string>
#include <vector>

// Forward declarations - avoid including FFmpeg headers in header file
struct AVFormatContext;
struct AVCodecContext;
struct AVFrame;
struct AVPacket;
struct SwrContext;

class FFmpegDecoder {
public:
    FFmpegDecoder();
    ~FFmpegDecoder();

    // Non-copyable
    FFmpegDecoder(const FFmpegDecoder&) = delete;
    FFmpegDecoder& operator=(const FFmpegDecoder&) = delete;

    // Open an audio file. Returns true on success.
    bool open(const std::string& filePath, uint32_t targetSampleRate = 48000, uint32_t targetChannels = 2);

    // Close and release resources
    void close();

    // Read PCM frames (interleaved float32)
    // Returns number of frames actually read (0 = EOF or error)
    uint64_t readPcmFrames(float* buffer, uint64_t framesToRead);

    // Seek to a specific PCM frame
    bool seekToPcmFrame(uint64_t frameIndex);

    // Get cursor position in PCM frames
    uint64_t getCursorInPcmFrames() const;

    // Get total length in PCM frames (may be 0 if unknown)
    uint64_t getLengthInPcmFrames() const;

    // Get output sample rate
    uint32_t getSampleRate() const { return m_outSampleRate; }

    // Get output channels
    uint32_t getChannels() const { return m_outChannels; }

    // Check if decoder is open and valid
    bool isOpen() const { return m_isOpen; }

    // Static: Check if a file can likely be decoded by FFmpeg
    // (quick check based on extension or FFmpeg probe)
    static bool canDecode(const std::string& filePath);

private:
    bool decodeNextPacket();
    void drainResampler();

    AVFormatContext* m_formatCtx = nullptr;
    AVCodecContext* m_codecCtx = nullptr;
    AVFrame* m_frame = nullptr;
    AVPacket* m_packet = nullptr;
    SwrContext* m_swrCtx = nullptr;

    int m_audioStreamIndex = -1;
    uint32_t m_outSampleRate = 48000;
    uint32_t m_outChannels = 2;
    uint64_t m_totalFrames = 0;
    uint64_t m_currentFrame = 0;

    // Internal buffer for resampled audio
    std::vector<float> m_resampleBuffer;
    size_t m_resampleBufferPos = 0;
    size_t m_resampleBufferSize = 0;

    bool m_isOpen = false;
    bool m_eof = false;
};
