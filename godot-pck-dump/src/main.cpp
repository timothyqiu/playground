#include <cstdio>
#include <exception>
#include <map>

#include <boost/algorithm/string/predicate.hpp>
#include <CLI/App.hpp>
#include <CLI/Formatter.hpp>
#include <CLI/Config.hpp>
#include <spdlog/spdlog.h>
#include <magic_enum.hpp>
#include <zstd.h>

#include "file.hpp"


class FileNotFound: public std::runtime_error {
public:
    explicit FileNotFound(std::string const& path) : std::runtime_error{path} {}
};


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
    static std::uint32_t const MAGIC = 0x43504447;  // GDPC

    explicit PCK(std::string const& path)
        : reader_{path}
    {
        if (reader_.pull_u32() != MAGIC) {
            reader_.seek_end();
            reader_.seek(reader_.get_position() - 4);
            if (reader_.pull_u32() != MAGIC) {
                throw std::runtime_error{"Invalid PCK"};
            }
            reader_.seek(reader_.get_position() - 4 - 8);
            auto const size = reader_.pull_u64();
            auto const pck_offset = reader_.get_position() - 8 - size;
            reader_.seek(pck_offset);
            if (reader_.pull_u32() != MAGIC) {
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
        for (std::uint32_t i = 0; i < file_count; i++) {
            auto const file_path = reader_.pull_string(reader_.pull_u32());
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
            throw FileNotFound{path};
        }
        auto const& entry = iter->second;
        reader_.seek(entry.offset);
        return reader_.pull_buffer(entry.size);
    }

    auto get_files() const -> std::vector<std::string>
    {
        std::vector<std::string> files;
        files.reserve(file_entries_.size());

        for (auto const& entry : file_entries_) {
            files.emplace_back(entry.first);
        }

        return files;
    }

    static void peel_embeded(std::string const& path, std::string const& output_path) {
        BinaryFileReader reader{path};

        spdlog::debug("Checking input...");
        if (reader.pull_u32() == MAGIC) {
            throw std::runtime_error{"Standalone PCK"};
        }
        reader.seek_end();
        reader.seek(reader.get_position() - 4);
        if (reader.pull_u32() != MAGIC) {
            throw std::runtime_error{"No PCK embeded"};
        }
        reader.seek(reader.get_position() - 4 - 8);
        auto const size = reader.pull_u64();
        auto const pck_offset = reader.get_position() - 8 - size;
        reader.seek(pck_offset);
        if (reader.pull_u32() != MAGIC) {
            throw std::runtime_error{"Invalid PCK"};
        }

        BinaryFileWriter writer{output_path};
        writer.push_u32(MAGIC);

        spdlog::debug("Copying header...");
        writer.push_buffer(reader.pull_buffer(4 * 20));

        auto const file_count = reader.pull_u32();
        spdlog::debug("Copying file table: {} entries...", file_count);
        writer.push_u32(file_count);
        for (auto i = 0u; i < file_count; i++) {
            auto const string_len = reader.pull_u32();
            writer.push_u32(string_len);
            writer.push_buffer(reader.pull_buffer(string_len));
            writer.push_u64(reader.pull_u64() - pck_offset);
            writer.push_u64(reader.pull_u64());
            writer.push_buffer(reader.pull_buffer(16));
        }

        spdlog::debug("Copying remaining data...");
        auto const remaining = size - (reader.get_position() - pck_offset);
        writer.push_buffer(reader.pull_buffer(remaining));
    }

private:
    struct FileEntry {
        std::uint64_t offset;
        std::uint64_t size;
    };

    std::map<std::string, FileEntry> file_entries_;
    BinaryFileReader reader_;
};


auto pull_project_settings_string(Reader& reader) -> std::string
{
    auto length = reader.pull_u32();
    if (length % 4) {
        length += 4 - length % 4;
    }
    return reader.pull_string(length);
}


auto format_project_settings_variant(Reader& reader, size_t indent = 0) -> std::string
{
    auto const type = reader.pull_u32();
    switch (type & 0xFF) {
    case 0:
        return "null";

    case 1:
        return fmt::format("{}", bool(reader.pull_u32()));

    case 2:
        if (type & (1 << 16)) {
            return fmt::format("{}", reader.pull_u64());
        } else {
            return fmt::format("{}", reader.pull_u32());
        }
        break;

    case 3:  // REAL
        if (type & (1 << 16)) {
            return fmt::format("{:.2f}", reader.pull_f64());
        } else {
            return fmt::format("{:.2f}", reader.pull_f32());
        }
        break;

    case 4:
        return fmt::format("\"{}\"", pull_project_settings_string(reader));

    case 14:  // COLOR
        {
            auto const r = reader.pull_f32();
            auto const g = reader.pull_f32();
            auto const b = reader.pull_f32();
            auto const a = reader.pull_f32();
            return fmt::format("Color({}, {}, {}, {})", r, g, b, a);
        }
        break;

    case 17:  // OBJECT
        {
            if (type & (1 << 16)) {
                auto const id = reader.pull_u64();
                return fmt::format("[Object: {}]", id);
            } else {
                auto const class_name = pull_project_settings_string(reader);
                if (class_name.empty()) {
                    return "null";
                }
                auto const count = reader.pull_u32();
                std::string entries;
                for (auto i = 0u; i < count; i++) {
                    auto const k = pull_project_settings_string(reader);
                    auto const v = format_project_settings_variant(reader, indent + 1);
                    entries += fmt::format("{}{} = {}\n", std::string(indent + 1, '\t'), k, v);
                }
                return fmt::format("[{}\n{}{}]", class_name, entries, std::string(indent, '\t'));
            }
        }
        break;

    case 18:  // DICTIONARY
        {
            auto const count = reader.pull_u32() & 0x7FFFFFFF;
            std::string entries;
            for (auto i = 0u; i < count; i++) {
                auto const k = format_project_settings_variant(reader, indent + 1);
                auto const v = format_project_settings_variant(reader, indent + 1);
                entries += fmt::format("{}{}: {},\n", std::string(indent + 1, '\t'), k, v);
            }
            return fmt::format("{{\n{}{}}}", entries, std::string(indent, '\t'));
        }
        break;

    case 19:  // ARRAY
        {
            auto const count = reader.pull_u32() & 0x7FFFFFFF;
            std::string entries;
            for (auto i = 0u; i < count; i++) {
                auto const v = format_project_settings_variant(reader, indent + 1);
                entries += fmt::format("{}{},\n", std::string(indent + 1, '\t'), v);
            }
            return fmt::format("[\n{}{}]", entries, std::string(indent, '\t'));
        }
        break;

    case 23:  // POOL_STRING_ARRAY
        {
            auto const count = reader.pull_u32();
            std::string entries;
            for (auto i = 0u; i < count; i++) {
                entries += fmt::format("\t\"{}\",\n", reader.pull_string(reader.pull_u32()));
            }
            return fmt::format("{{\n{}}}", entries);
        }
        break;

    default:
        return fmt::format("[DATA type:{}]", type);
    }
}


void dump_project_settings(Reader& reader)
{
    auto const count = reader.pull_u32();
    for (std::uint32_t i = 0; i < count; i++) {
        auto const name = reader.pull_string(reader.pull_u32());
        auto const value = reader.pull_buffer(reader.pull_u32());
        BufferReader value_reader{value.data(), value.size()};
        fmt::print("{}: {}\n", name, format_project_settings_variant(value_reader));
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

    if (format & (1 << 20)) {
        fmt::print("PNG image\n");
    }
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


void dump_gdscript(Reader& reader)
{
    auto const version = reader.pull_u32();
    if (version > 13) {
        throw std::runtime_error{fmt::format("Unsupported Bytecode Version: {}", version)};
    }

    std::vector<std::string> identifiers;
    std::vector<std::string> constants;

    identifiers.resize(reader.pull_u32());
    constants.resize(reader.pull_u32());
    auto const line_count = reader.pull_u32();
    auto const token_count = reader.pull_u32();

    spdlog::debug("Identifiers: {}", identifiers.size());
    for (auto &identifier : identifiers) {
        identifier = reader.pull_string(reader.pull_u32());
        for (auto &c : identifier) {
            c ^= 0xb6;
        }
    }

    spdlog::debug("Constants: {}", constants.size());
    for (auto &constant : constants) {
        constant = format_project_settings_variant(reader);
    }

    spdlog::debug("Lines: {}", line_count);
    reader.skip(4 * 2 * line_count);

    std::string newline;
    auto &br = dynamic_cast<BufferReader &>(reader);
    for (auto i = 0u; i < token_count; i++) {
        unsigned int raw_token;
        if (br.peek_u8() & 0x80) {
            raw_token = br.pull_u32() & ~0x80u;
        } else {
            raw_token = br.pull_u8();
        }

        auto const token = raw_token & ((1 << 8) - 1);
        switch (token) {
        case 1:     fmt::print("{}", identifiers[raw_token >> 8]);    break;
        case 2:     fmt::print("{}", constants[raw_token >> 8]);      break;
        case 3:     fmt::print("self"); break;
        case 4: {
            auto const type = raw_token >> 8;
            static char const *const names[] = {
                "null",
                "bool", "int", "float", "String",
                "Vector2", "Rect2", "Transform2D",
                "Vector3", "AABB", "Plane", "Quat", "Basis", "Transform",
                "Color", "RID", "Object", "NodePath",
                "Dictionary", "Array",
                "PoolByteArray",
                "PoolIntArray",
                "PoolRealArray",
                "PoolStringArray",
                "PoolVector2Array",
                "PoolVector3Array",
                "PoolColorArray",
            };
            if (type >= sizeof(names) / sizeof(names[0])) {
                fmt::print("[TYPE {}]", type);
            } else {
                fmt::print("{}", names[type]);
            }
        } break;
        case 5: {
            auto const func = raw_token >> 8;
            switch (func) {
            case 38:    fmt::print("randi");    break;
            case 41:    fmt::print("seed");    break;
            case 63:    fmt::print("print");    break;
            case 76:    fmt::print("load");     break;
            case 88:    fmt::print("len");     break;
            default:    fmt::print("[func {}]", func);
            }
        } break;
        case 6:     fmt::print(" in "); break;
        case 7:     fmt::print(" == "); break;
        case 8:     fmt::print(" != "); break;
        case 9:     fmt::print(" < "); break;
        case 10:    fmt::print(" <= "); break;
        case 11:    fmt::print(" > "); break;
        case 12:    fmt::print(" >= "); break;
        case 13:    fmt::print(" and "); break;
        case 14:    fmt::print(" or "); break;
        case 15:    fmt::print(" not "); break;
        case 16:    fmt::print(" + "); break;
        case 17:    fmt::print(" - "); break;
        case 18:    fmt::print(" * "); break;
        case 19:    fmt::print(" / "); break;
        case 20:    fmt::print(" % "); break;
        case 21:    fmt::print(" << "); break;
        case 22:    fmt::print(" >> "); break;
        case 23:    fmt::print(" = "); break;
        case 24:    fmt::print(" += "); break;
        case 25:    fmt::print(" -= "); break;
        case 26:    fmt::print(" *= "); break;
        case 27:    fmt::print(" /= "); break;
        case 28:    fmt::print(" %= "); break;
        case 29:    fmt::print(" <<= "); break;
        case 30:    fmt::print(" >>= "); break;
        case 31:    fmt::print(" &= "); break;
        case 32:    fmt::print(" |= "); break;
        case 33:    fmt::print(" ^= "); break;
        case 34:    fmt::print(" & "); break;
        case 35:    fmt::print(" | "); break;
        case 36:    fmt::print(" ^ "); break;
        case 37:    fmt::print(" ~ "); break;
        case 38:    fmt::print("if "); break;
        case 39:    fmt::print("elif "); break;
        case 40:    fmt::print("else "); break;
        case 41:    fmt::print("for "); break;
        case 42:    fmt::print("while "); break;
        case 43:    fmt::print("break"); break;
        case 44:    fmt::print("continue"); break;
        case 45:    fmt::print("pass"); break;
        case 46:    fmt::print("return "); break;
        case 47:    fmt::print("match "); break;
        case 48:    fmt::print("func "); break;
        case 49:    fmt::print("class "); break;
        case 50:    fmt::print("class_name "); break;
        case 51:    fmt::print("extends "); break;
        case 52:    fmt::print(" is "); break;
        case 53:    fmt::print("onready "); break;
        case 54:    fmt::print("tool "); break;
        case 55:    fmt::print("static "); break;
        case 56:    fmt::print("export "); break;
        case 57:    fmt::print(" setget "); break;
        case 58:    fmt::print("const "); break;
        case 59:    fmt::print("var "); break;
        case 60:    fmt::print(" as "); break;
        case 61:    fmt::print(" void "); break;
        case 62:    fmt::print("enum "); break;
        case 63:    fmt::print("preload"); break;
        case 64:    fmt::print("assert"); break;
        case 65:    fmt::print("yield"); break;
        case 66:    fmt::print("signal "); break;

        case 76:    fmt::print("["); break;
        case 77:    fmt::print("]"); break;
        case 78:    fmt::print("{{"); break;
        case 79:    fmt::print("}}"); break;
        case 80:    fmt::print("("); break;
        case 81:    fmt::print(")"); break;
        case 82:    fmt::print(", "); break;
        case 83:    fmt::print(";"); break;
        case 84:    fmt::print("."); break;
        case 85:    fmt::print("?"); break;
        case 86:    fmt::print(":"); break;
        case 87:    fmt::print("$"); break;
        case 88:    fmt::print("->"); break;
        case 89:
            {
                std::string current_newline = "\n";
                auto const indent = raw_token >> 8;
                for (auto j = 0u; j < indent; j++) {
                    current_newline += "    ";
                }
                if (current_newline != newline) {
                    newline = current_newline;
                    fmt::print("{}", newline);
                }
            }
            break;

        default:
            fmt::print("[TK {}]", token);
            break;
        }

        if (token != 89 && !newline.empty()) {
            newline = "";
        }
    }
}


void save_file(std::string const& binary_path, std::string const& file_path, std::string const& output_path, bool use_png)
{
    PCK pck{binary_path};

    std::string path = file_path;
    std::vector<uint8_t> data;
    try {
        data = pck.get_file(path);
    }
    catch (FileNotFound const&) {
        data = pck.get_file(path + ".import");
        auto const value = get_ini_value(reinterpret_cast<char const *>(data.data()), data.size(), "remap", "path");
        auto const remap_path = value.substr(1, value.size() - 2);  // quotes
        data = pck.get_file(remap_path);
        path = remap_path;
    }

    auto const n = path.rfind(".stex");
    if (use_png && (n != path.npos) && (n == path.size() - 5)) {
        try {
            spdlog::info("Extracting PNG from .stex");

            BufferReader reader{data.data(), data.size()};
            if (reader.pull_string(4) != "GDST") {
                throw std::runtime_error{"Not PNG"};
            }

            reader.skip(2 * 4 + 4);
            auto const format = reader.pull_u32();
            if ((format & (1 << 20)) == 0) {
                throw std::runtime_error{"Not PNG"};
            }
            reader.skip(4);  // mipmap count

            auto const size = reader.pull_u32();
            if (reader.pull_string(4) != "PNG ") {
                throw std::runtime_error{"Corrupted Data: invalid PNG magic"};
            }
            auto const buffer = reader.pull_buffer(size - 4);
            BinaryFileWriter{output_path + ".png"}.push_buffer(buffer);
            return;
        }
        catch (std::exception const& e) {
            if (e.what() != std::string{"Not PNG"}) {
                spdlog::warn("Failed to extract PNG from .stex: {}", e.what());
            }
        }
    }

    BinaryFileWriter{output_path}.push_buffer(data);
}


void inspect_file(std::string const& binary_path, std::string const& path)
{
    PCK pck{binary_path};

    std::vector<uint8_t> data;
    try {
        data = pck.get_file(path);
    }
    catch (FileNotFound const&) {
        data = pck.get_file(path + ".import");
        auto const value = get_ini_value(reinterpret_cast<char const *>(data.data()), data.size(), "remap", "path");
        auto const remap_path = value.substr(1, value.size() - 2);  // quotes
        data = pck.get_file(remap_path);
    }
    spdlog::debug("file size: {} bytes", data.size());

    BufferReader reader{data.data(), data.size()};

    if (is_plain_text(path)) {
        fmt::print("{}", reader.pull_string(data.size()));
    } else {
        std::map<std::string, std::function<void(Reader&)>> const format_readers = {
            { "ECFG", dump_project_settings },
            { "GDST", dump_stream_texture },
            { "RSCC", dump_compressed_resource },
            { "RSRC", dump_resource },
            { "GDSC", dump_gdscript },
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
    CLI::App app{"Godot PCK Tools"};
    app.require_subcommand(1);

    bool verbose = false;
    app.add_flag("--verbose", verbose, "Verbose Output");

    std::string binary_path;
    app.add_option("path", binary_path, "PCK/EXE file path")->required();

    auto inspect = app.add_subcommand("inspect", "Inspect file inside PCK");
    std::string file_path = "res://project.binary";
    inspect->add_option("file-path", file_path, "File path inside PCK");

    auto save = app.add_subcommand("save", "Save file from PCK");
    std::string output_path;
    bool use_png = true;
    save->add_flag("--png,!--no-png", use_png, "Save as PNG when possible");
    save->add_option("file-path", file_path, "File path inside PCK")->required();
    save->add_option("output-path", output_path, "File output path")->required();

    auto list = app.add_subcommand("list", "List files inside PCK");

    auto peel = app.add_subcommand("peel", "Peel embeded PCK");
    peel->add_option("output-path", output_path, "PCK output path")->required();

    CLI11_PARSE(app, argc, argv);

    spdlog::set_level(verbose ? spdlog::level::debug : spdlog::level::warn);

    if (app.got_subcommand(inspect)) {
        inspect_file(binary_path, file_path);
    } else if (app.got_subcommand(list)) {
        for (auto const& path : PCK{binary_path}.get_files()) {
            fmt::print("{}\n", path);
        }
    } else if (app.got_subcommand(peel)) {
        PCK::peel_embeded(binary_path, output_path);
    } else if (app.got_subcommand(save)) {
        save_file(binary_path, file_path, output_path, use_png);
    }
}
catch (std::exception const& e) {
    spdlog::error("Uncaught exception: {}", e.what());
}
