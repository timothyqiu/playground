#ifndef HAZEL_LOG_HPP_
#define HAZEL_LOG_HPP_

#include <hazel/export.hpp>

#include <spdlog/spdlog.h>

namespace hazel {

class HAZEL_API Log
{
public:
    static void init();

    static auto core_logger() { return s_core_logger_.get(); }
    static auto client_logger() { return s_client_logger_.get(); }

private:
    static std::shared_ptr<spdlog::logger> s_core_logger_;
    static std::shared_ptr<spdlog::logger> s_client_logger_;
};

}  // namespace hazel

#define HZ_CORE_TRACE(...) ::hazel::Log::core_logger()->trace(__VA_ARGS__)
#define HZ_CORE_DEBUG(...) ::hazel::Log::core_logger()->debug(__VA_ARGS__)
#define HZ_CORE_INFO(...) ::hazel::Log::core_logger()->info(__VA_ARGS__)
#define HZ_CORE_WARN(...) ::hazel::Log::core_logger()->warn(__VA_ARGS__)
#define HZ_CORE_ERROR(...) ::hazel::Log::core_logger()->error(__VA_ARGS__)

#define HZ_TRACE(...) ::hazel::Log::client_logger()->trace(__VA_ARGS__)
#define HZ_DEBUG(...) ::hazel::Log::client_logger()->debug(__VA_ARGS__)
#define HZ_INFO(...) ::hazel::Log::client_logger()->info(__VA_ARGS__)
#define HZ_WARN(...) ::hazel::Log::client_logger()->warn(__VA_ARGS__)
#define HZ_ERROR(...) ::hazel::Log::client_logger()->error(__VA_ARGS__)

#endif  // HAZEL_LOG_HPP_
