#ifndef BLD_INFLATOR_HPP_
#define BLD_INFLATOR_HPP_

#include <cstdint>
#include <vector>

std::vector<std::uint8_t> decompress(void const *data, std::size_t size);

#endif  // BLD_INFLATOR_HPP_
