const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "blive-danmaku",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    b.installArtifact(exe);

    if (b.systemIntegrationOption("mbedtls", .{})) {
        exe.linkSystemLibrary("mbedtls");
        exe.linkSystemLibrary("mbedx509");
        exe.linkSystemLibrary("mbedcrypto");
    } else if (b.lazyDependency("mbedtls", .{
        .target = target,
        .optimize = optimize,
    })) |mbedtls_dep| {
        const lib = b.addStaticLibrary(.{
            .name = "mbedtls",
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        });
        lib.addIncludePath(mbedtls_dep.path("include"));
        lib.installHeadersDirectory(mbedtls_dep.path("include"), "", .{});
        lib.addCSourceFiles(.{
            .root = mbedtls_dep.path("library"),
            .files = mbedtls_files,
        });
        if (target.result.os.tag == .windows) {
            lib.linkSystemLibrary("ws2_32");
            lib.linkSystemLibrary("bcrypt");
        }
        exe.linkLibrary(lib);
    }

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

const mbedtls_files = &.{
    // mbedcrypto
    "aes.c",
    "aesni.c",
    "aesce.c",
    "aria.c",
    "asn1parse.c",
    "asn1write.c",
    "base64.c",
    "bignum.c",
    "bignum_core.c",
    "bignum_mod.c",
    "bignum_mod_raw.c",
    "block_cipher.c",
    "camellia.c",
    "ccm.c",
    "chacha20.c",
    "chachapoly.c",
    "cipher.c",
    "cipher_wrap.c",
    "cmac.c",
    "constant_time.c",
    "ctr_drbg.c",
    "des.c",
    "dhm.c",
    "ecdh.c",
    "ecdsa.c",
    "ecjpake.c",
    "ecp.c",
    "ecp_curves.c",
    "ecp_curves_new.c",
    "entropy.c",
    "entropy_poll.c",
    "error.c",
    "gcm.c",
    "hkdf.c",
    "hmac_drbg.c",
    "lmots.c",
    "lms.c",
    "md.c",
    "md5.c",
    "memory_buffer_alloc.c",
    "nist_kw.c",
    "oid.c",
    "padlock.c",
    "pem.c",
    "pk.c",
    "pk_ecc.c",
    "pk_wrap.c",
    "pkcs12.c",
    "pkcs5.c",
    "pkparse.c",
    "pkwrite.c",
    "platform.c",
    "platform_util.c",
    "poly1305.c",
    "psa_crypto.c",
    "psa_crypto_aead.c",
    "psa_crypto_cipher.c",
    "psa_crypto_client.c",
    "psa_crypto_driver_wrappers_no_static.c",
    "psa_crypto_ecp.c",
    "psa_crypto_ffdh.c",
    "psa_crypto_hash.c",
    "psa_crypto_mac.c",
    "psa_crypto_pake.c",
    "psa_crypto_rsa.c",
    "psa_crypto_se.c",
    "psa_crypto_slot_management.c",
    "psa_crypto_storage.c",
    "psa_its_file.c",
    "psa_util.c",
    "ripemd160.c",
    "rsa.c",
    "rsa_alt_helpers.c",
    "sha1.c",
    "sha256.c",
    "sha512.c",
    "sha3.c",
    "threading.c",
    "timing.c",
    "version.c",
    "version_features.c",
    // mbedx509
    "x509.c",
    "x509_create.c",
    "x509_crl.c",
    "x509_crt.c",
    "x509_csr.c",
    "x509write.c",
    "x509write_crt.c",
    "x509write_csr.c",
    "pkcs7.c",
    // mbedtls
    "debug.c",
    "mps_reader.c",
    "mps_trace.c",
    "net_sockets.c",
    "ssl_cache.c",
    "ssl_ciphersuites.c",
    "ssl_client.c",
    "ssl_cookie.c",
    "ssl_debug_helpers_generated.c",
    "ssl_msg.c",
    "ssl_ticket.c",
    "ssl_tls.c",
    "ssl_tls12_client.c",
    "ssl_tls12_server.c",
    "ssl_tls13_keys.c",
    "ssl_tls13_client.c",
    "ssl_tls13_server.c",
    "ssl_tls13_generic.c",
};
