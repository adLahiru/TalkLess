// ffmpeg_decoder.cpp
// FFmpeg-based audio decoder implementation

#include "ffmpeg_decoder.h"

#ifdef TALKLESS_HAS_FFMPEG
#if TALKLESS_HAS_FFMPEG

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libswresample/swresample.h>
}

#include <algorithm>
#include <cstring>
#include <iostream>

#ifdef _WIN32
#include <windows.h>
static std::wstring utf8ToWideFFmpeg(const std::string& utf8) {
    if (utf8.empty()) return std::wstring();
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, nullptr, 0);
    if (wlen <= 0) return std::wstring();
    std::wstring wstr(wlen, L'\0');
    MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), -1, &wstr[0], wlen);
    if (!wstr.empty() && wstr.back() == L'\0') wstr.pop_back();
    return wstr;
}
#endif

FFmpegDecoder::FFmpegDecoder() = default;

FFmpegDecoder::~FFmpegDecoder() {
    close();
}

bool FFmpegDecoder::open(const std::string& filePath, uint32_t targetSampleRate, uint32_t targetChannels) {
    close();

    m_outSampleRate = targetSampleRate;
    m_outChannels = targetChannels;

    // Open input file
    m_formatCtx = nullptr;
    // avformat_open_input will allocate the context


    int ret = avformat_open_input(&m_formatCtx, filePath.c_str(), nullptr, nullptr);
    if (ret < 0) {
        char errbuf[256];
        av_strerror(ret, errbuf, sizeof(errbuf));
        std::cerr << "[FFmpegDecoder] Failed to open file: " << filePath << " - " << errbuf << "\n";
        close();
        return false;
    }

    // Find stream info
    ret = avformat_find_stream_info(m_formatCtx, nullptr);
    if (ret < 0) {
        std::cerr << "[FFmpegDecoder] Failed to find stream info\n";
        close();
        return false;
    }

    // Find the best audio stream
    m_audioStreamIndex = av_find_best_stream(m_formatCtx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    if (m_audioStreamIndex < 0) {
        std::cerr << "[FFmpegDecoder] No audio stream found\n";
        close();
        return false;
    }

    AVStream* audioStream = m_formatCtx->streams[m_audioStreamIndex];
    const AVCodec* codec = avcodec_find_decoder(audioStream->codecpar->codec_id);
    if (!codec) {
        std::cerr << "[FFmpegDecoder] Unsupported codec\n";
        close();
        return false;
    }

    std::cout << "[FFmpegDecoder] Using codec: " << codec->name << "\n";

    // Allocate codec context
    m_codecCtx = avcodec_alloc_context3(codec);
    if (!m_codecCtx) {
        std::cerr << "[FFmpegDecoder] Failed to allocate codec context\n";
        close();
        return false;
    }

    ret = avcodec_parameters_to_context(m_codecCtx, audioStream->codecpar);
    if (ret < 0) {
        std::cerr << "[FFmpegDecoder] Failed to copy codec parameters\n";
        close();
        return false;
    }

    ret = avcodec_open2(m_codecCtx, codec, nullptr);
    if (ret < 0) {
        std::cerr << "[FFmpegDecoder] Failed to open codec\n";
        close();
        return false;
    }

    // Setup resampler
    AVChannelLayout outLayout;
    av_channel_layout_default(&outLayout, targetChannels);

    ret = swr_alloc_set_opts2(&m_swrCtx,
        &outLayout, AV_SAMPLE_FMT_FLT, targetSampleRate,
        &m_codecCtx->ch_layout, m_codecCtx->sample_fmt, m_codecCtx->sample_rate,
        0, nullptr);

    if (ret < 0 || !m_swrCtx) {
        std::cerr << "[FFmpegDecoder] Failed to create resampler\n";
        close();
        return false;
    }

    ret = swr_init(m_swrCtx);
    if (ret < 0) {
        std::cerr << "[FFmpegDecoder] Failed to initialize resampler\n";
        close();
        return false;
    }

    // Allocate frame and packet
    m_frame = av_frame_alloc();
    m_packet = av_packet_alloc();
    if (!m_frame || !m_packet) {
        std::cerr << "[FFmpegDecoder] Failed to allocate frame/packet\n";
        close();
        return false;
    }

    // Calculate total frames
    if (audioStream->duration > 0 && audioStream->time_base.den > 0) {
        double durationSec = (double)audioStream->duration * av_q2d(audioStream->time_base);
        m_totalFrames = (uint64_t)(durationSec * targetSampleRate);
    } else if (m_formatCtx->duration > 0) {
        double durationSec = (double)m_formatCtx->duration / AV_TIME_BASE;
        m_totalFrames = (uint64_t)(durationSec * targetSampleRate);
    }

    m_currentFrame = 0;
    m_eof = false;
    m_isOpen = true;

    std::cout << "[FFmpegDecoder] Opened: " << filePath 
              << " (SR: " << m_codecCtx->sample_rate 
              << " -> " << targetSampleRate 
              << ", Duration: " << (m_totalFrames / targetSampleRate) << "s)\n";

    return true;
}

void FFmpegDecoder::close() {
    if (m_swrCtx) {
        swr_free(&m_swrCtx);
        m_swrCtx = nullptr;
    }
    if (m_frame) {
        av_frame_free(&m_frame);
        m_frame = nullptr;
    }
    if (m_packet) {
        av_packet_free(&m_packet);
        m_packet = nullptr;
    }
    if (m_codecCtx) {
        avcodec_free_context(&m_codecCtx);
        m_codecCtx = nullptr;
    }
    if (m_formatCtx) {
        avformat_close_input(&m_formatCtx);
        m_formatCtx = nullptr;
    }

    m_audioStreamIndex = -1;
    m_totalFrames = 0;
    m_currentFrame = 0;
    m_resampleBuffer.clear();
    m_resampleBufferPos = 0;
    m_resampleBufferSize = 0;
    m_isOpen = false;
    m_eof = false;
}

bool FFmpegDecoder::decodeNextPacket() {
    if (!m_isOpen || m_eof) return false;

    while (true) {
        int ret = av_read_frame(m_formatCtx, m_packet);
        if (ret < 0) {
            if (ret == AVERROR_EOF) {
                m_eof = true;
            }
            return false;
        }

        if (m_packet->stream_index != m_audioStreamIndex) {
            av_packet_unref(m_packet);
            continue;
        }

        ret = avcodec_send_packet(m_codecCtx, m_packet);
        av_packet_unref(m_packet);

        if (ret < 0) {
            continue;
        }

        ret = avcodec_receive_frame(m_codecCtx, m_frame);
        if (ret == AVERROR(EAGAIN)) {
            continue;
        }
        if (ret == AVERROR_EOF) {
            m_eof = true;
            return false;
        }
        if (ret < 0) {
            return false;
        }

        // We have a decoded frame - resample it
        int outSamples = swr_get_out_samples(m_swrCtx, m_frame->nb_samples);
        if (outSamples <= 0) {
            av_frame_unref(m_frame);
            continue;
        }

        // Resize buffer if needed
        size_t neededSize = outSamples * m_outChannels;
        if (m_resampleBuffer.size() < neededSize) {
            m_resampleBuffer.resize(neededSize);
        }

        uint8_t* outBuf[1] = { reinterpret_cast<uint8_t*>(m_resampleBuffer.data()) };
        int converted = swr_convert(m_swrCtx, outBuf, outSamples,
            (const uint8_t**)m_frame->extended_data, m_frame->nb_samples);

        av_frame_unref(m_frame);

        if (converted > 0) {
            m_resampleBufferPos = 0;
            m_resampleBufferSize = converted * m_outChannels;
            return true;
        }
    }

    return false;
}

uint64_t FFmpegDecoder::readPcmFrames(float* buffer, uint64_t framesToRead) {
    if (!m_isOpen) return 0;

    uint64_t framesRead = 0;
    uint64_t samplesNeeded = framesToRead * m_outChannels;

    while (framesRead < framesToRead) {
        // First, drain any buffered resampled data
        if (m_resampleBufferPos < m_resampleBufferSize) {
            size_t available = m_resampleBufferSize - m_resampleBufferPos;
            size_t needed = (framesToRead - framesRead) * m_outChannels;
            size_t toCopy = std::min(available, needed);

            std::memcpy(buffer + (framesRead * m_outChannels),
                       m_resampleBuffer.data() + m_resampleBufferPos,
                       toCopy * sizeof(float));

            m_resampleBufferPos += toCopy;
            framesRead += toCopy / m_outChannels;
            continue;
        }

        // Need more data - decode next packet
        if (!decodeNextPacket()) {
            break; // EOF or error
        }
    }

    m_currentFrame += framesRead;
    return framesRead;
}

bool FFmpegDecoder::seekToPcmFrame(uint64_t frameIndex) {
    if (!m_isOpen || !m_formatCtx) return false;

    AVStream* stream = m_formatCtx->streams[m_audioStreamIndex];
    
    // Convert frame index to stream timestamp
    double timestampSec = (double)frameIndex / m_outSampleRate;
    int64_t timestamp = (int64_t)(timestampSec / av_q2d(stream->time_base));

    // Seek to the requested position
    int ret = av_seek_frame(m_formatCtx, m_audioStreamIndex, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        // Try seeking in the file instead
        int64_t fileTimestamp = (int64_t)(timestampSec * AV_TIME_BASE);
        ret = av_seek_frame(m_formatCtx, -1, fileTimestamp, AVSEEK_FLAG_BACKWARD);
        if (ret < 0) {
            return false;
        }
    }

    // Flush codec buffers
    avcodec_flush_buffers(m_codecCtx);

    // Clear resample buffer
    m_resampleBufferPos = 0;
    m_resampleBufferSize = 0;
    m_currentFrame = frameIndex;
    m_eof = false;

    return true;
}

uint64_t FFmpegDecoder::getCursorInPcmFrames() const {
    return m_currentFrame;
}

uint64_t FFmpegDecoder::getLengthInPcmFrames() const {
    return m_totalFrames;
}

bool FFmpegDecoder::canDecode(const std::string& filePath) {
    // Quick probe - try to open and find an audio stream
    AVFormatContext* ctx = nullptr;
    int ret = avformat_open_input(&ctx, filePath.c_str(), nullptr, nullptr);
    if (ret < 0) {
        return false;
    }

    ret = avformat_find_stream_info(ctx, nullptr);
    if (ret < 0) {
        avformat_close_input(&ctx);
        return false;
    }

    int audioIdx = av_find_best_stream(ctx, AVMEDIA_TYPE_AUDIO, -1, -1, nullptr, 0);
    bool hasAudio = (audioIdx >= 0);

    avformat_close_input(&ctx);
    return hasAudio;
}

#else // TALKLESS_HAS_FFMPEG == 0

// Stub implementations when FFmpeg is not available
FFmpegDecoder::FFmpegDecoder() = default;
FFmpegDecoder::~FFmpegDecoder() = default;

bool FFmpegDecoder::open(const std::string&, uint32_t, uint32_t) {
    std::cerr << "[FFmpegDecoder] FFmpeg support not compiled in\n";
    return false;
}
void FFmpegDecoder::close() {}
uint64_t FFmpegDecoder::readPcmFrames(float*, uint64_t) { return 0; }
bool FFmpegDecoder::seekToPcmFrame(uint64_t) { return false; }
uint64_t FFmpegDecoder::getCursorInPcmFrames() const { return 0; }
uint64_t FFmpegDecoder::getLengthInPcmFrames() const { return 0; }
bool FFmpegDecoder::canDecode(const std::string&) { return false; }
bool FFmpegDecoder::decodeNextPacket() { return false; }
void FFmpegDecoder::drainResampler() {}

#endif // TALKLESS_HAS_FFMPEG

#else // !defined(TALKLESS_HAS_FFMPEG)

#include <iostream>

// Stub implementations when FFmpeg macro is not defined
FFmpegDecoder::FFmpegDecoder() = default;
FFmpegDecoder::~FFmpegDecoder() = default;

bool FFmpegDecoder::open(const std::string&, uint32_t, uint32_t) {
    std::cerr << "[FFmpegDecoder] FFmpeg support not compiled in\n";
    return false;
}
void FFmpegDecoder::close() {}
uint64_t FFmpegDecoder::readPcmFrames(float*, uint64_t) { return 0; }
bool FFmpegDecoder::seekToPcmFrame(uint64_t) { return false; }
uint64_t FFmpegDecoder::getCursorInPcmFrames() const { return 0; }
uint64_t FFmpegDecoder::getLengthInPcmFrames() const { return 0; }
bool FFmpegDecoder::canDecode(const std::string&) { return false; }
bool FFmpegDecoder::decodeNextPacket() { return false; }
void FFmpegDecoder::drainResampler() {}

#endif // TALKLESS_HAS_FFMPEG
