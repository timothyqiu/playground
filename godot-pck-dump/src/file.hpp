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
    virtual auto seek(std::uint64_t pos) -> void = 0;

    [[nodiscard]] auto pull_u8() -> std::uint8_t;
    [[nodiscard]] auto pull_u16() -> std::uint16_t;
    [[nodiscard]] auto pull_u32() -> std::uint32_t;
    [[nodiscard]] auto pull_u64() -> std::uint64_t;
    [[nodiscard]] auto pull_f32() -> float;
    [[nodiscard]] auto pull_f64() -> double;
    [[nodiscard]] auto pull_buffer(std::size_t size) -> std::vector<std::uint8_t>;
    [[nodiscard]] auto pull_string(std::size_t size) -> std::string;

    [[nodiscard]] virtual auto get_position() const -> std::uint64_t = 0;

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
    auto seek(std::uint64_t pos) -> void override;
    auto get_position() const -> std::uint64_t override;

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

    auto seek(std::uint64_t pos) -> void override;
    auto get_position() const -> std::uint64_t override;

    auto skip(std::size_t size) -> void override;

    auto peek_u8() -> std::uint8_t;

private:
    std::uint8_t const *data_;
    std::size_t const size_;
    std::size_t read_index_;

    auto prepare_read(std::size_t size) const -> std::uint8_t const * override;
    auto commit_read(std::size_t size) -> void override;
};


class BinaryFileWriter
{
public:
    explicit BinaryFileWriter(std::string const& path);
    ~BinaryFileWriter();

    BinaryFileWriter(BinaryFileWriter const&);
    BinaryFileWriter& operator=(BinaryFileWriter const&);

    auto get_position() const -> std::uint64_t;

    void push_u32(std::uint32_t v);
    void push_u64(std::uint64_t v);
    void push_buffer(std::vector<std::uint8_t> const& buffer);

    void skip(std::size_t size);

private:
    FILE *file_;

    void commit_write(void const *data, std::size_t size);
};

#endif  // FILE_HPP_
