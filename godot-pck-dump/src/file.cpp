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
