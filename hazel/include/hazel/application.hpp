#ifndef HAZEL_APPLICATION_HPP_
#define HAZEL_APPLICATION_HPP_

#include <memory>

#include <hazel/export.hpp>

namespace hazel {

class HAZEL_API Application
{
public:
    Application();
    virtual ~Application();

    Application(Application const&) = delete;
    Application& operator=(Application const&) = delete;

    void run();
};

auto create_application() -> std::unique_ptr<Application>;

}  // namespace hazel

#endif  // HAZEL_APPLICATION_HPP_
