#ifndef DEMO_SCOPE_EXIT_HPP_
#define DEMO_SCOPE_EXIT_HPP_

template <typename F>
class ScopeExit final
{
public:
    ScopeExit(F f) : f_{f} {}
    ~ScopeExit() { f_(); }

    ScopeExit(ScopeExit const&) = delete;
    ScopeExit& operator=(ScopeExit const&) = delete;

private:
    F f_;
};

template <typename F>
ScopeExit<F> make_scope_exit(F f) {
    return ScopeExit<F>{f};
}

#define DO_STRING_JOIN(x, y) x ## y
#define STRING_JOIN(x, y) DO_STRING_JOIN(x, y)
#define SCOPE_EXIT(code)    \
    auto STRING_JOIN(scope_exit_, __LINE__) = make_scope_exit([=](){ code; })

#endif  // DEMO_SCOPE_EXIT_HPP_
