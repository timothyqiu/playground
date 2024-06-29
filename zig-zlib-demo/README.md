# Zig Zlib Demo

This is a demonstration of how to compile Zlib using Zig and use deflate and inflate.

The Zlib is built from source into a static library.

```
zig build run
```

To link system Zlib instead:

```
zig build -fsys=zlib run
```
