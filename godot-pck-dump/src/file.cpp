#include "file.hpp"
#include <cerrno>
#include <cstring>
#include <stdexcept>
#include <boost/endian/conversion.hpp>
#include <fmt/format.h>


BinaryFileReader::BinaryFileReader(std::string const& path)
    : file_{fopen(path.c_str(), "rb")}
{
    if (file_ == nullptr) {
        throw std::runtime_error{
#if defined(_POSIX_C_SOURCE) and _POSIX_C_SOURCE >= 200809L
            std::strerror(errno)
#else
            "fopen"
#endif
        };
    }
}


BinaryFileReader::~BinaryFileReader()
{
    std::fclose(file_);
}


auto BinaryFileReader::prepare_read(std::size_t size) const -> std::uint8_t const *
{
    buffer_.resize(size);

    if (std::fread(buffer_.data(), buffer_.size(), 1, file_) < 1) {
        throw std::runtime_error{"fread: not enough data"};
    }
    return buffer_.data();
}


auto BinaryFileReader::seek_end() -> void
{
    if (std::fseek(file_, 0, SEEK_END) != 0) {
        throw std::runtime_error{fmt::format("fseek(0, END): {}", std::strerror(errno))};
    }
}


auto BinaryFileReader::seek(std::uint64_t pos) -> void
{
    if (std::fseek(file_, static_cast<long>(pos), SEEK_SET) != 0) {
        throw std::runtime_error{fmt::format("fseek({}, SET): {}", pos, std::strerror(errno))};
    }
}


auto BinaryFileReader::get_position() const -> std::uint64_t
{
    auto const pos = std::ftell(file_);
    if (pos < 0) {
        throw std::runtime_error{fmt::format("ftell: {}", std::strerror(errno))};
    }
    return static_cast<std::uint64_t>(pos);
}


auto BinaryFileReader::skip(std::size_t size) -> void
{
    if (std::fseek(file_, static_cast<long>(size), SEEK_CUR) != 0) {
        throw std::runtime_error{fmt::format("fseek({}, CUR): {}", size, std::strerror(errno))};
    }
}


auto BinaryFileReader::commit_read(std::size_t) -> void
{
    // FIXME: rollback not implemented
}


BufferReader::BufferReader(void const *data, std::size_t size)
    : data_{static_cast<std::uint8_t const *>(data)}, size_{size}, read_index_{0}
{
}


auto BufferReader::prepare_read(std::size_t size) const -> std::uint8_t const *
{
    if (read_index_ + size > size_) {
        throw std::runtime_error{fmt::format("prepare_read({}): not enough data", size)};
    }
    return data_ + read_index_;
}


auto BufferReader::commit_read(std::size_t size) -> void
{
    read_index_ += size;
}


auto BufferReader::seek(std::uint64_t pos) -> void
{
    read_index_ = pos;
}


auto BufferReader::get_position() const -> std::uint64_t
{
    return read_index_;
}


auto BufferReader::skip(std::size_t size) -> void
{
    if (read_index_ + size > size_) {
        throw std::runtime_error{fmt::format("skip({}): not enough data", size)};
    }
    read_index_ += size;
}


auto BufferReader::peek_u8() -> std::uint8_t
{
    return *this->prepare_read(1);
}


auto Reader::pull_u8() -> std::uint8_t
{
    auto const size = sizeof(std::uint8_t);
    auto const v = *this->prepare_read(size);
    this->commit_read(size);
    return v;
}


auto Reader::pull_u16() -> std::uint16_t
{
    auto const size = sizeof(std::uint16_t);
    auto const v = boost::endian::load_little_u16(this->prepare_read(size));
    this->commit_read(size);
    return v;
}


auto Reader::pull_u32() -> std::uint32_t
{
    auto const size = sizeof(std::uint32_t);
    auto const v = boost::endian::load_little_u32(this->prepare_read(size));
    this->commit_read(size);
    return v;
}


auto Reader::pull_u64() -> std::uint64_t
{
    auto const size = sizeof(std::uint64_t);
    auto const v = boost::endian::load_little_u64(this->prepare_read(size));
    this->commit_read(size);
    return v;
}


auto Reader::pull_f32() -> float
{
    union Marshall {
        std::uint32_t u32;
        float f32;
    } m;
    m.u32 = this->pull_u32();
    return m.f32;
}


auto Reader::pull_f64() -> double
{
    union Marshall {
        std::uint64_t u64;
        double f64;
    } m;
    m.u64 = this->pull_u64();
    return m.f64;
}


auto Reader::pull_buffer(std::size_t size) -> std::vector<std::uint8_t>
{
    auto const p = this->prepare_read(size);
    this->commit_read(size);
    return {p, p + size};
}


auto Reader::pull_string(std::size_t size) -> std::string
{
    std::vector<char> buffer(size + 1);

    auto const p = this->prepare_read(size);
    this->commit_read(size);

    std::memcpy(buffer.data(), p, size);
    buffer[size] = '\0';

    return buffer.data();
}


BinaryFileWriter::BinaryFileWriter(std::string const& path)
    : file_{fopen(path.c_str(), "wb")}
{
    if (file_ == nullptr) {
        throw std::runtime_error{
#if defined(_POSIX_C_SOURCE) and _POSIX_C_SOURCE >= 200809L
            std::strerror(errno)
#else
            "fopen"
#endif
        };
    }
}

BinaryFileWriter::~BinaryFileWriter()
{
    fclose(file_);
}

auto BinaryFileWriter::get_position() const -> std::uint64_t
{
    auto const pos = std::ftell(file_);
    if (pos < 0) {
        throw std::runtime_error{fmt::format("ftell: {}", std::strerror(errno))};
    }
    return static_cast<std::uint64_t>(pos);
}

void BinaryFileWriter::commit_write(void const *data, std::size_t size)
{
    if (std::fwrite(data, size, 1, file_) < 1) {
        throw std::runtime_error{"fwrite"};
    }
}

void BinaryFileWriter::push_buffer(std::vector<std::uint8_t> const& buffer)
{
    this->commit_write(buffer.data(), buffer.size());
}

void BinaryFileWriter::push_buffer(std::uint8_t const *data, std::size_t size)
{
    this->commit_write(data, size);
}

void BinaryFileWriter::push_u32(std::uint32_t v)
{
    constexpr auto const size = sizeof(std::uint32_t);
    std::uint8_t buffer[size];
    boost::endian::store_little_u32(buffer, v);
    this->commit_write(buffer, size);
}

void BinaryFileWriter::push_u64(std::uint64_t v)
{
    constexpr auto const size = sizeof(std::uint64_t);
    std::uint8_t buffer[size];
    boost::endian::store_little_u64(buffer, v);
    this->commit_write(buffer, size);
}

void BinaryFileWriter::skip(std::size_t size)
{
    std::vector<std::uint8_t> buffer(size);
    this->push_buffer(buffer);
}

std::string get_ini_value(char const *data, size_t size,
                          std::string const& section, std::string const& key)
{
    bool is_current_section = false;
    bool is_current_value = false;

    bool is_start_of_line = true;
    bool is_inside_braces = false;

    size_t start_of_value = 0;

    for (auto i = 0u; i < size; i++) {
        switch (data[i]) {
        case '[':
            if (is_start_of_line) {
                for (auto j = i; i < size; j++) {
                    if (data[j] == ']') {
                        std::string current_section{data + i + 1, j - i - 1};
                        is_current_section = current_section == section;
                        i = j;
                        break;
                    }
                }
            }
            break;
        case '\n':
            if (!is_inside_braces) {
                if (is_current_value) {
                    return std::string{data + start_of_value, i - start_of_value};
                }
                is_start_of_line = true;
            }
            break;
        case '{':
            is_inside_braces = true;
            break;
        case '}':
            is_inside_braces = false;
            break;
        default:
            if (is_start_of_line) {
                if (is_current_section) {
                    for (auto j = i; j < size; j++) {
                        if (data[j] == '=') {
                            std::string current_key{data + i, j - i};
                            is_current_value = current_key == key;
                            start_of_value = j + 1;
                            i = j;
                            break;
                        }
                    }
                }
                is_start_of_line = false;
            }
            break;
        }
    }

    throw std::runtime_error{fmt::format("INI key {} not found", key)};
}
