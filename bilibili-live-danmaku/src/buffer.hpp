#ifndef BLD_BUFFER_HPP_
#define BLD_BUFFER_HPP_

#include <algorithm>
#include <cassert>
#include <cstdint>
#include <stdexcept>
#include <string>
#include <vector>

#include <boost/endian/conversion.hpp>


class ReadBuffer
{
public:
    explicit ReadBuffer(void const *data, std::size_t size)
        : data_{static_cast<std::uint8_t const *>(data)}, size_{size}, read_index_{0}
    {
    }

    auto begin() const -> std::uint8_t const * { return data_ + read_index_; }
    auto end() const -> std::uint8_t const * { return data_ + size_; }
    auto size() const -> std::size_t { return size_ - read_index_; }

    auto pull_u16(std::size_t offset=0) -> std::uint16_t
    {
        auto const v = this->peek_u16(offset);
        read_index_ += sizeof(v);
        return v;
    }
    auto pull_u32(std::size_t offset=0) -> std::uint32_t
    {
        auto const v = this->peek_u32(offset);
        read_index_ += sizeof(v);
        return v;
    }
    auto pull_buffer(std::size_t size) -> ReadBuffer
    {
        ReadBuffer buffer{this->prepare_read(0, size), size};
        read_index_ += size;
        return buffer;
    }

    auto peek_u16(std::size_t offset=0) const -> std::uint16_t
    {
        auto const size = sizeof(std::uint16_t);
        return boost::endian::load_big_u16(this->prepare_read(offset, size));
    }
    auto peek_u32(std::size_t offset=0) const -> std::uint32_t
    {
        auto const size = sizeof(std::uint32_t);
        return boost::endian::load_big_u32(this->prepare_read(offset, size));
    }
    auto peek_string() const -> std::string
    {
        return {this->begin(), this->end()};
    }

private:
    std::uint8_t const *data_;
    std::size_t const size_;
    std::size_t read_index_;

    auto prepare_read(std::size_t offset, std::size_t size) const -> std::uint8_t const *
    {
        if (read_index_ + offset + size > size_) {
            throw std::runtime_error{"not enough data"};
        }
        return data_ + read_index_ + offset;
    }
};


class WriteBuffer
{
public:
    explicit WriteBuffer(std::size_t size)
        : buffer_(size), write_index_{0}
    {
    }

    auto done() -> std::vector<std::uint8_t>
    {
        buffer_.resize(write_index_);
        write_index_ = 0;
        return std::move(buffer_);
    }

    auto begin() const -> std::uint8_t const * { return buffer_.data(); }
    auto end() const -> std::uint8_t const * { return buffer_.data() + write_index_; }
    auto size() const -> std::size_t { return write_index_; }

    auto push_u16(std::uint16_t v) -> void
    {
        auto const size = sizeof(v);
        boost::endian::store_big_u16(this->prepare_write(size), v);
        write_index_ += size;
    }
    auto push_u32(std::uint32_t v) -> void
    {
        auto const size = sizeof(v);
        boost::endian::store_big_u32(this->prepare_write(size), v);
        write_index_ += size;
    }
    auto push_data(void const *data, std::size_t size) -> void
    {
        std::memcpy(this->prepare_write(size), data, size);
        write_index_ += size;
    }

private:
    std::vector<std::uint8_t> buffer_;
    std::size_t write_index_;

    auto prepare_write(std::size_t size) -> std::uint8_t *
    {
        auto const target_size = write_index_ + size;
        auto const actual_size = buffer_.size();
        if (target_size > actual_size) {
            buffer_.resize(std::max(target_size, actual_size * 2));
        }
        return buffer_.data() + write_index_;
    }
};

#endif  // BLD_BUFFER_HPP_
