#ifndef countof
#define countof(x) (sizeof(x) / sizeof((x)[0]))
#endif

template<typename T, typename... Args>
std::unique_ptr<T> make_unique(Args&&... args) {
    return std::unique_ptr<T>(new T(std::forward<Args>(args)...));
}
