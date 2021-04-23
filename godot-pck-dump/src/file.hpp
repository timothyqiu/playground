#ifndef FILE_HPP_
#define FILE_HPP_

#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <string>
#include <vector>


class Reader
{
public:
    virtual ~Reader() = default;

    virtual auto skip(std::size_t size) -> void = 0;

    [[nodiscard]] auto pull_u32() -> std::uint32_t;
    [[nodiscard]] auto pull_u64() -> std::uint64_t;
    [[nodiscard]] auto pull_buffer(std::size_t size) -> std::vector<std::uint8_t>;
    [[nodiscard]] auto pull_string(std::size_t size) -> std::string;

protected:
    virtual auto prepare_read(std::size_t size) const -> std::uint8_t const * = 0;
    virtual auto commit_read(std::size_t size) -> void = 0;
};


class BinaryFileReader: public Reader
{
public:
    explicit BinaryFileReader(std::string const& path);
    ~BinaryFileReader();

    BinaryFileReader(BinaryFileReader const&) = delete;
    BinaryFileReader& operator=(BinaryFileReader const&) = delete;

    auto seek_end() -> void;
    auto seek(std::uint64_t pos) -> void;
    auto get_position() const -> std::uint64_t;

    auto skip(std::size_t size) -> void override;

private:
    FILE *file_;
    mutable std::vector<std::uint8_t> buffer_;  // use prepare_read to update this

    auto prepare_read(std::size_t size) const -> std::uint8_t const * override;
    auto commit_read(std::size_t size) -> void override;
};


class BufferReader: public Reader
{
public:
    explicit BufferReader(void const *data, std::size_t size);

    auto skip(std::size_t size) -> void override;

private:
    std::uint8_t const *data_;
    std::size_t const size_;
    std::size_t read_index_;

    auto prepare_read(std::size_t size) const -> std::uint8_t const * override;
    auto commit_read(std::size_t size) -> void override;
};

#endif  // FILE_HPP_
