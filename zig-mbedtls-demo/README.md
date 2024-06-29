# Zig MbedTLS Demo

This is a demonstration of how to compile MbedTLS using Zig and use the library for HTTPS requests.

The MbedTLS is built from source into a static library.

```
zig build run
```

To link system MbedTLS instead:

```
zig build -fsys=mbedtls run
```
