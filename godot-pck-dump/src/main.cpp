#include <cstdio>
#include <exception>
#include <unordered_map>

#include <boost/algorithm/string/predicate.hpp>
#include <spdlog/spdlog.h>
#include <magic_enum.hpp>
#include <zstd.h>

#include "config.hpp"
#include "file.hpp"


bool is_plain_text(std::string const& path)
{
    static char const *plain_text_extensions[] = {
        ".tscn", ".tres", ".import", ".remap", ".shader",
    };

    for (auto const ext : plain_text_extensions) {
        if (boost::algorithm::ends_with(path, ext)) {
            return true;
        }
    }
    return false;
}

enum class CompressionMode { FASTLZ, DEFLATE, ZSTD, GZIP };

CompressionMode cast_to_compression_mode(std::uint32_t v)
{
    if (v > magic_enum::enum_count<CompressionMode>()) {
        throw std::runtime_error{fmt::format("Unexpected CompressionMode: {}", v)};
    }
    return static_cast<CompressionMode>(v);
}

class PCK
{
public:
    explicit PCK(std::string const& path)
        : reader_{path}
    {
        std::uint32_t const magic = 0x43504447;  // GDPK
        if (reader_.pull_u32() != magic) {
            reader_.seek_end();
            reader_.seek(reader_.get_position() - 4);
            if (reader_.pull_u32() != magic) {
                throw std::runtime_error{"Invalid PCK"};
            }
            reader_.seek(reader_.get_position() - 4 - 8);
            auto const size = reader_.pull_u64();
            reader_.seek(reader_.get_position() - 8 - size);
            if (reader_.pull_u32() != magic) {
                throw std::runtime_error{"Invalid PCK"};
            }
        }

        auto const version = reader_.pull_u32();
        if (version > 1) {
            throw std::runtime_error{fmt::format("Unsupported file version: {}", version)};
        }

        auto const major = reader_.pull_u32();
        auto const minor = reader_.pull_u32();
        auto const patch = reader_.pull_u32();
        if (major < 3 || (major == 3 && minor < 2)) {
            spdlog::info("Created by Godot Engine: {}.{}.X", major, minor);
        } else {
            spdlog::info("Created by Godot Engine: {}.{}.{}", major, minor, patch);
        }
        reader_.skip(16 * 4);

        auto const file_count = reader_.pull_u32();
        file_entries_.reserve(file_count);

        for (std::uint32_t i = 0; i < file_count; i++) {
            auto const file_path = reader_.pull_string(reader_.pull_u32());
            spdlog::debug("Entry {}", file_path);
            auto const offset = reader_.pull_u64();
            auto const size = reader_.pull_u64();
            file_entries_.emplace(std::make_pair(file_path, FileEntry{offset, size}));
            reader_.skip(16);  // md5
        }
    }

    auto get_file(std::string const& path) -> std::vector<std::uint8_t>
    {
        auto const iter = file_entries_.find(path);
        if (iter == std::end(file_entries_)) {
            throw std::runtime_error{fmt::format("{} does not exist", path)};
        }
        auto const& entry = iter->second;
        reader_.seek(entry.offset);
        return reader_.pull_buffer(entry.size);
    }

private:
    struct FileEntry {
        std::uint64_t offset;
        std::uint64_t size;
    };

    std::unordered_map<std::string, FileEntry> file_entries_;
    BinaryFileReader reader_;
};


void dump_project_settings(Reader& reader)
{
    auto const count = reader.pull_u32();
    for (std::uint32_t i = 0; i < count; i++) {
        auto const name = reader.pull_string(reader.pull_u32());

        auto const value = reader.pull_buffer(reader.pull_u32());
        BufferReader value_reader{value.data(), value.size()};

        auto const type = value_reader.pull_u32();
        switch (type & 0xFF) {
        case 0:
            fmt::print("{}: null\n", name);
            break;

        case 1:
            fmt::print("{}: {}\n", name, bool(value_reader.pull_u32()));
            break;

        case 2:
            if (type & (1 << 16)) {
                fmt::print("{}: {}\n", name, value_reader.pull_u64());
            } else {
                fmt::print("{}: {}\n", name, value_reader.pull_u32());
            }
            break;

        case 4:
            fmt::print("{}: \"{}\"\n", name, value_reader.pull_string(value_reader.pull_u32()));
            break;

        case 18:
            fmt::print("{}: {{ ... }}\n", name);
            break;

        case 19:
            fmt::print("{}: [ ... ]\n", name);
            break;

        default:
            fmt::print("{}: (DATA type:{} size:{})\n", name, type, value.size());
            break;
        }
    }
}


void dump_stream_texture(Reader& reader)
{
    auto const w = reader.pull_u16();
    auto const pw = reader.pull_u16();
    auto const h = reader.pull_u16();
    auto const ph = reader.pull_u16();
    auto const flags = reader.pull_u32();
    auto const format = reader.pull_u32();
    if (pw == 0 && ph ==0) {
        fmt::print("StreamTexture FLAG[{:x}] FMT[{:x}] {}x{}\n", flags, format, w, h);
    } else {
        fmt::print("StreamTexture FLAG[{:x}] FMT[{:x}] {}x{} -> {}x{}\n", flags, format, w, h, pw, ph);
    }
    // TODO: extract?
}


void dump_resource(Reader& reader)
{
    auto const big_endian = static_cast<bool>(reader.pull_u32());
    auto const use_real64 = static_cast<bool>(reader.pull_u32());
    if (big_endian || use_real64) {
        throw std::runtime_error{fmt::format("Unsupported format: big_endian {}, use_real64 {}", big_endian, use_real64)};
    }
    auto const major = reader.pull_u32();
    auto const minor = reader.pull_u32();
    auto const version_format = reader.pull_u32();
    if (version_format > 3 || major > 3) {
        throw std::runtime_error{fmt::format("Version: {}.{}, Format: {}\n", major, minor, version_format)};
    }
    fmt::print("Type: {}\n", reader.pull_string(reader.pull_u32()));

    reader.skip(4 * 16);

    std::vector<std::string> string_table(reader.pull_u32());
    for (auto& entry : string_table) {
        entry = reader.pull_string(reader.pull_u32());
    }
    spdlog::debug("String table size: {}", string_table.size());

    std::vector<std::pair<std::string, std::string>> ext_resources(reader.pull_u32());
    for (auto& entry : ext_resources) {
        entry.first = reader.pull_string(reader.pull_u32());
        entry.second = reader.pull_string(reader.pull_u32());
    }
    spdlog::debug("Ext resource count: {}", ext_resources.size());

    std::vector<std::pair<std::string, std::uint64_t>> int_resources(reader.pull_u32());
    for (auto& entry : int_resources) {
        entry.first = reader.pull_string(reader.pull_u32());
        entry.second = reader.pull_u64();
    }
    spdlog::debug("Int resource count: {}", int_resources.size());

    auto const main_resource = int_resources.front();
    reader.seek(main_resource.second);
    fmt::print("Main Resource Type: {}\n", reader.pull_string(reader.pull_u32()));

    auto const properties_count = reader.pull_u32();
    for (auto i = 0u; i < properties_count; i++) {
        auto const string_id = reader.pull_u32();
        if (string_id & 0x80000000) {
            throw std::runtime_error{fmt::format("not implemented for string id: 0x{0:x}", string_id)};
        }
        auto const& name = string_table[string_id];
        if (name.empty()) {
            throw std::runtime_error{"Empty property name"};
        }

        auto const type = reader.pull_u32();
        switch (type) {
        case 2:  // BOOL
            fmt::print("{} = {}\n", name, static_cast<bool>(reader.pull_u32()));
            break;
        case 3:  // INT
            fmt::print("{} = {}\n", name, reader.pull_u32());
            break;
        case 4:  // REAL
            // real = f32 since we errored out previously :)
            fmt::print("{} = {}\n", name, reader.pull_f32());
            break;
        case 5:  // STRING
            fmt::print("{} = {}\n", name, reader.pull_string(reader.pull_u32()));
            break;
        case 12:  // Vector3
            {
                // real = f32 since we errored out previously :)
                auto const x = reader.pull_f32();
                auto const y = reader.pull_f32();
                auto const z = reader.pull_f32();
                fmt::print("{} = Vector3({}, {}, {})\n", name, x, y, z);
            }
            break;
        case 20:  // COLOR
            {
                // real = f32 since we errored out previously :)
                auto const r = reader.pull_f32();
                auto const g = reader.pull_f32();
                auto const b = reader.pull_f32();
                auto const a = reader.pull_f32();
                fmt::print("{} = Color(RGBA: {}, {}, {}, {})\n", name, r, g, b, a);
            }
            break;
        case 24:  // OBJECT
            {
                auto const object_type = reader.pull_u32();
                switch (object_type) {
                case 3:  // EXTERNAL RESOURCE INDEX
                    {
                        auto const index = reader.pull_u32();
                        if (index >= ext_resources.size()) {
                            throw std::runtime_error{fmt::format("external resource index out of bound for {}: {}", name, index)};
                        }
                        auto const& res = ext_resources[index];
                        fmt::print("{} = ext_resource({}: \"{}\")\n", name, res.first, res.second);
                    }
                    break;
                default:
                    throw std::runtime_error{fmt::format("unhandled object type for {}: {}", name, object_type)};
                }
            }
            break;
        default:
            throw std::runtime_error{fmt::format("unhandled variant type for {}: {}", name, type)};
        }
    }
}


void dump_compressed_resource(Reader& reader)
{
    auto const compression_mode = cast_to_compression_mode(reader.pull_u32());
    auto const block_size = reader.pull_u32();
    if (block_size == 0) {
        throw std::runtime_error{fmt::format("Zero block size.")};
    }
    auto const read_total = reader.pull_u32();
    auto const block_count = (read_total / block_size) + 1;
    spdlog::debug("{} Compressed Resource: block size {}, read total {}, blocks {}\n",
                  magic_enum::enum_name(compression_mode), block_size, read_total, block_count);

    std::vector<std::uint64_t> compressed_sizes(block_count);
    for (auto i = 0u; i < block_count; i++) {
        compressed_sizes[i] = reader.pull_u32();
    }

    std::vector<uint8_t> decompressed;
    size_t decompressed_total = 0;
    for (auto i = 0u; i < block_count; i++) {
        decompressed.resize(decompressed_total + block_size);

        auto const& compressed = reader.pull_buffer(compressed_sizes[i]);
        auto const decompressed_size = ZSTD_decompress(decompressed.data() + decompressed_total, block_size,
                                                       compressed.data(), compressed.size());
        if (ZSTD_isError(decompressed_size)) {
            auto const error = decompressed_size;
            throw std::runtime_error{fmt::format("ZSTD decompress error {}: {}", error, ZSTD_getErrorName(error))};
        }
        spdlog::debug("Block #{}: {} => {}\n", i, compressed.size(), decompressed_size);
        decompressed_total += decompressed_size;
    }

    BufferReader decompressed_reader{decompressed.data(), decompressed_total};
    dump_resource(decompressed_reader);
}


void inspect(std::string const& binary_path, std::string const& path)
{
    PCK pck{binary_path};

    auto const data = pck.get_file(path);
    spdlog::debug("file size: {} bytes", data.size());

    BufferReader reader{data.data(), data.size()};

    if (is_plain_text(path)) {
        fmt::print("{}", reader.pull_string(data.size()));
    } else {
        std::unordered_map<std::string, std::function<void(Reader&)>> const format_readers = {
            { "ECFG", dump_project_settings },
            { "GDST", dump_stream_texture },
            { "RSCC", dump_compressed_resource },
            { "RSRC", dump_resource },
        };
        auto const& magic = reader.pull_string(4);
        auto const iter = format_readers.find(magic);
        if (iter == format_readers.end()) {
            throw std::runtime_error{fmt::format("unknown file magic: {}", magic)};
        }
        iter->second(reader);
    }
}


int main(int argc, char *argv[])
try {
    Config const config{argc, argv};

    inspect(config.path, config.file_path);
}
catch (std::exception const& e) {
    spdlog::error("Uncaught exception: {}", e.what());
}
