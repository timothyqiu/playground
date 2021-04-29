#include <cstdio>
#include <exception>
#include <unordered_map>

#include <spdlog/spdlog.h>

#include "config.hpp"
#include "file.hpp"


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
            spdlog::debug("Entry {} size {}", file_path, file_path.size());
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


void dump_project_settings(PCK& pck, std::string const& path)
{
    auto const data = pck.get_file(path);
    BufferReader reader{data.data(), data.size()};

    if (reader.pull_u32() != 0x47464345) {  // ECFG
        throw std::runtime_error{"Invalid ProjectSettings"};
    }
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


int main(int argc, char *argv[])
try {
    Config const config{argc, argv};

    PCK pck{config.path};

    if (config.file_path.empty()) {
        dump_project_settings(pck, "res://project.binary");
    } else {
        auto const data = pck.get_file(config.file_path);
        BufferReader reader{data.data(), data.size()};

        auto const& magic = reader.pull_string(4);
        if (magic == "GDST") {
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
        } else {
            fmt::print("{} bytes\n", data.size());
        }
    }
}
catch (std::exception const& e) {
    spdlog::error("Uncaught exception: {}", e.what());
}
