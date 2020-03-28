#include <hazel/hazel.hpp>

class SandboxApplication: public hazel::Application
{
public:
    SandboxApplication()
    {
    }

    ~SandboxApplication() override
    {
    }
};

// The Hazel engine series puts main in the engine
auto main() -> int
{
    hazel::Log::init();

    HZ_CORE_WARN("Initialized log!");
    HZ_INFO("Hello");

    SandboxApplication{}.run();
}
