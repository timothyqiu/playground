#include <stdexcept>
#include <string>

#include <CLI/App.hpp>
#include <CLI/Config.hpp>
#include <CLI/Formatter.hpp>
#include <spdlog/spdlog.h>

#include "file.hpp"

static uint32_t g_section_alignment = 0;
static uint32_t g_file_alignment = 0;
static uint32_t g_rva_base = 0;

static uint32_t align(uint32_t value, uint32_t alignment)
{
    if ((alignment > 0) && (value % alignment) > 0) {
        return value + (alignment - (value % alignment));
    }
    return value;
}
static uint32_t rva_to_offset(uint32_t section_virtual_address, uint32_t section_raw_data, uint32_t rva)
{
    auto const va = align(section_virtual_address, g_section_alignment);
    auto const offset = align(section_raw_data, g_file_alignment);
    return (rva - va) + offset;
}

static void dump_resource_data(Reader &reader, std::string const& label, uint32_t sor, int level);
static void dump_directory(Reader &reader, std::string const& label, uint32_t sor, int level);
static void dump_directory_entry(Reader& reader, uint32_t sor, int level);

static void dump_resource_data(Reader &reader, std::string const& label, uint32_t sor, int level)
{
    std::string indent;
    for (auto i = 0; i < level; i++) {
        indent += "  ";
    }

    auto const offset_to_data = reader.pull_u32();
    auto const size = reader.pull_u32();
    auto const code_page = reader.pull_u32();
    reader.skip(4);  // Reserved

    static int i = 0;
    std::string path = fmt::format("/tmp/dump-res-{:02}", i++);
    auto const current = reader.get_position();
    reader.seek(g_rva_base + offset_to_data);
    BinaryFileWriter{path}.push_buffer(reader.pull_buffer(size));
    reader.seek(current);

    fmt::print("{}Data {} [offset]0x{:x} [size]{} [codepage]{}\n", indent, label, offset_to_data, size, code_page);
}

static void dump_directory_entry(Reader& reader, uint32_t sor, int level)
{
    auto const name = reader.pull_u32();
    auto const offset = reader.pull_u32();

    std::string name_info;
    if (name & 0x80000000) {
        auto const string_offset = name & 0x7FFFFFFF;
        name_info = fmt::format("Name-{}", string_offset);
    } else {
        name_info = fmt::format("ID-{}", name);
        if (level == 1) {
            switch (name & 0x7FFFFFFF) {
            case 3:
                name_info += "(ICON)";
                break;
            case 6:
                name_info += "(STRING)";
                break;
            }
        }
    }

    std::string data_info;
    auto const data_offset = offset & 0x7FFFFFFF;
    auto const current = reader.get_position();
    reader.seek(sor + data_offset);
    if (offset & 0x80000000) {
        dump_directory(reader, name_info, sor, level);
    } else {
        dump_resource_data(reader, name_info, sor, level);
    }
    reader.seek(current);
};

static void dump_directory(Reader &reader, std::string const& label, uint32_t sor, int level)
{
    reader.skip(4 * 2);  // Characteristics, Time/Date Stamp
    auto const major_version = reader.pull_u16();
    auto const minor_version = reader.pull_u16();

    std::string indent;
    for (auto i = 0; i < level; i++) {
        indent += "  ";
    }

    fmt::print("{}Directory {} version[{}.{}]\n", indent, label, major_version, minor_version);

    auto const number_of_named_entries = reader.pull_u16();
    for (auto i = 0u; i < number_of_named_entries; i++) {
        dump_directory_entry(reader, sor, level + 1);
    }
    auto const number_of_id_entries = reader.pull_u16();
    for (auto i = 0u; i < number_of_id_entries; i++) {
        dump_directory_entry(reader, sor, level + 1);
    }
}

static void dump_resource(Reader& reader)
{
    auto const start = reader.get_position();
    dump_directory(reader, "Root", start, 0);
}

static void dump(std::string const& path)
{
    BinaryFileReader reader{path};

    if (auto const sig = reader.pull_u16(); sig != 0x5A4D) {  // 'M', 'Z'
        throw std::runtime_error{fmt::format("Invalid DOS Header: 0x{:x}", sig)};
    }
    reader.seek(0x3C);
    reader.seek(reader.pull_u32());
    if (auto const sig = reader.pull_u32(); sig != 0x4550) {  // 'P', 'E', 0, 0
        throw std::runtime_error{fmt::format("Invalid Signature: 0x{:x}", sig)};
    }
    fmt::print("Machine: 0x{:x}\n", reader.pull_u16());

    auto const number_of_sections = reader.pull_u16();
    fmt::print("NumberOfSections: {}\n", number_of_sections);

    fmt::print("TimeDateStamp: {}\n", reader.pull_u32());
    fmt::print("PointerToSymbolTable: {}\n", reader.pull_u32());
    fmt::print("NumberOfSymbolTable: {}\n", reader.pull_u32());
    auto const size_of_optional_header = reader.pull_u16();
    fmt::print("SizeOfOptionalHeader: {}\n", size_of_optional_header);
    fmt::print("Characteristics: 0x{:x}\n", reader.pull_u16());
    auto const end_of_pe_header = reader.get_position();

    fmt::print("Magic: 0x{:x}\n", reader.pull_u16());
    fmt::print("MajorLinkerVersion: {}\n", reader.pull_u8());
    fmt::print("MinorLinkerVersion: {}\n", reader.pull_u8());
    fmt::print("SizeOfCode: {}\n", reader.pull_u32());
    fmt::print("SizeOfInitializedData: {}\n", reader.pull_u32());
    fmt::print("SizeOfUninitializedData: {}\n", reader.pull_u32());
    fmt::print("AddressOfEntryPoint: 0x{:x}\n", reader.pull_u32());
    fmt::print("BaseOfCode: 0x{:x}\n", reader.pull_u32());
    fmt::print("BaseOfData: 0x{:x}\n", reader.pull_u32());

    auto const image_base = reader.pull_u32();
    fmt::print("ImageBase: 0x{:x}\n", image_base);

    g_section_alignment = reader.pull_u32();
    fmt::print("SectionAlignment: 0x{:x}\n", g_section_alignment);
    g_file_alignment = reader.pull_u32();
    fmt::print("FileAlignment: 0x{:x}\n", g_file_alignment);
    fmt::print("MajorOperatingSystemVersion: {}\n", reader.pull_u16());
    fmt::print("MinorOperatingSystemVersion: {}\n", reader.pull_u16());
    fmt::print("MajorImageVersion: {}\n", reader.pull_u16());
    fmt::print("MinorImageVersion: {}\n", reader.pull_u16());
    fmt::print("MajorSubsystemVersion: {}\n", reader.pull_u16());
    fmt::print("MinorSubsystemVersion: {}\n", reader.pull_u16());
    fmt::print("Win32VersionValue: {}\n", reader.pull_u32());
    fmt::print("SizeOfImage: {}\n", reader.pull_u32());
    fmt::print("SizeOfHeaders: {}\n", reader.pull_u32());
    fmt::print("CheckSum: 0x{:x}\n", reader.pull_u32());
    fmt::print("Subsystem: 0x{:x}\n", reader.pull_u16());
    fmt::print("DllCharacteristics: 0x{:x}\n", reader.pull_u16());
    fmt::print("SizeOfStackReserve: {}\n", reader.pull_u32());
    fmt::print("SizeOfStackCommit: {}\n", reader.pull_u32());
    fmt::print("SizeOfHeapReserve: {}\n", reader.pull_u32());
    fmt::print("SizeOfHeapCommit: {}\n", reader.pull_u32());
    fmt::print("LoaderFlags: 0x{:x}\n", reader.pull_u32());
    auto const number_of_rva_and_sizes = reader.pull_u32();
    fmt::print("NumberOfRvaAndSizes: {}\n", number_of_rva_and_sizes);

    bool resource_address_found = false;
    uint32_t resource_address = 0;
    uint32_t resource_size = 0;

    auto const dump_image_data_directory = [&reader](std::string const& name) -> std::pair<uint32_t, uint32_t> {
        auto const address = reader.pull_u32();
        auto const size = reader.pull_u32();
        fmt::print("{}: 0x{:x} size {}\n", name, address, size);
        return {address, size};
    };
    for (auto i = 0u; i < number_of_rva_and_sizes; i++) {
        auto const address = reader.pull_u32();
        auto const size = reader.pull_u32();
        if (i == 2) {
            resource_address = address;
            resource_size = size;
            resource_address_found = true;
        }
    }

    reader.seek(end_of_pe_header + size_of_optional_header);

    for (auto i = 0u; i < number_of_sections; i++) {
        fmt::print("[Section #{}]\n", i);

        auto const name = reader.pull_string(8);
        fmt::print("\tName: \"{}\"\n", name);

        auto const virtual_size = reader.pull_u32();
        auto const address = reader.pull_u32();
        fmt::print("\tVirtualSize: {}\n", virtual_size);
        fmt::print("\tVirtualAddress: 0x{:x}\n", address);
        auto const size_of_raw_data = reader.pull_u32();
        fmt::print("\tSizeOfRawData: {0} (0x{0:x})\n", size_of_raw_data);
        auto const raw_data = reader.pull_u32();
        fmt::print("\tPointerToRawData: 0x{:x}\n", raw_data);
        fmt::print("\tPointerToRelocations: 0x{:x}\n", reader.pull_u32());
        fmt::print("\tPointerToLinenumbers: 0x{:x}\n", reader.pull_u32());
        fmt::print("\tNumberOfRelocations: {}\n", reader.pull_u16());
        fmt::print("\tNumberOfLinenumbers: {}\n", reader.pull_u16());
        fmt::print("\tCharacteristics: 0x{:x}\n", reader.pull_u32());

        bool is_resource_section = false;
        if (resource_address_found) {
            auto const size = virtual_size > 0 ? virtual_size : size_of_raw_data;
            if ((address <= resource_address) && (resource_address + resource_size <= address + size)) {
                is_resource_section = true;
            }
        } else if (name == ".rsrc") {
            is_resource_section = true;
        }

        if (is_resource_section) {
            fmt::print("\t[Resource Directory Is Here]\n");
            g_rva_base = raw_data - address;
            if (resource_address == 0) {
                resource_address = address;
            }
            reader.seek(g_rva_base + resource_address);
            dump_resource(reader);
            return;
        }
    }
}


int main(int argc, char *argv[])
try {
    CLI::App app{"PE Dump"};

    bool verbose = false;
    app.add_flag("--verbose", verbose, "Verbose Output");

    std::string path = "build/example.exe";
    app.add_option("path", path, "Executable path");

    CLI11_PARSE(app, argc, argv);

    dump(path);
}
catch (std::exception const& e) {
    spdlog::error("Uncaught exception: {}", e.what());
}
