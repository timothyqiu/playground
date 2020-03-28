#include "hazel/log.hpp"

#include <spdlog/sinks/stdout_color_sinks.h>

namespace hazel {

std::shared_ptr<spdlog::logger> Log::s_core_logger_;
std::shared_ptr<spdlog::logger> Log::s_client_logger_;

void Log::init()
{
    spdlog::set_pattern("%^[%T] %n: %v%$");

    s_core_logger_ = spdlog::stdout_color_mt("hazel");
    s_core_logger_->set_level(spdlog::level::trace);

    s_client_logger_ = spdlog::stdout_color_mt("app");
    s_client_logger_->set_level(spdlog::level::trace);
}

}  // namespace hazel
