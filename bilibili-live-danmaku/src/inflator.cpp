#include "inflator.hpp"
#include <stdexcept>
#include <fmt/core.h>
#include <zlib.h>

std::vector<std::uint8_t> decompress(void const *data, std::size_t size)
{
    z_stream strm;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    strm.opaque = Z_NULL;
    strm.avail_in = size;
    strm.next_in = const_cast<std::uint8_t *>(static_cast<std::uint8_t const *>(data));

    int ret = inflateInit(&strm);
    if (ret != Z_OK) {
        throw std::runtime_error{fmt::format("inflateInit: {}", ret)};
    }

    std::vector<std::uint8_t> output;
    output.resize(size * 3);

    std::size_t inflated = 0;

    do {
        strm.avail_out = output.size() - inflated;
        strm.next_out = output.data() + inflated;

        // Z_STREAM_END: finish
        // Z_OK: some progress
        // Z_NEED_DICT
        // Z_DATA_ERROR: input corrupted, check strm->msg
        // Z_STREAM_ERROR: strm inconsistent
        // Z_MEM_ERROR: not enough memory
        // Z_BUF_ERROR: no possible output
        ret = inflate(&strm, Z_FINISH);

        switch (ret) {
        case Z_STREAM_END:
            // Done
            break;

        case Z_BUF_ERROR:
        case Z_OK:
            // Need more output space or input data
            inflated = strm.total_out;
            output.resize(output.size() * 2);
            break;

        case Z_NEED_DICT:
        case Z_DATA_ERROR:
        case Z_STREAM_ERROR:
        case Z_MEM_ERROR:
            inflateEnd(&strm);
            throw std::runtime_error{fmt::format("inflate: {}", ret)};
        }

    } while (ret != Z_STREAM_END);

    output.resize(strm.total_out);
    inflateEnd(&strm);

    return output;
}
