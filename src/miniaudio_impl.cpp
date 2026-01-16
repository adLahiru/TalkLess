// miniaudio_impl.cpp
// This file implements miniaudio with support for OGG/Vorbis files

// Enable stb_vorbis for OGG decoding support in miniaudio
// stb_vorbis must be included BEFORE miniaudio.h
#define STB_VORBIS_HEADER_ONLY
#include "stb_vorbis.c"  // This provides the declarations

// Now include miniaudio with the implementation
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

// Include the stb_vorbis implementation 
// (must be after miniaudio since it uses the declarations above)
#undef STB_VORBIS_HEADER_ONLY
#include "stb_vorbis.c"
