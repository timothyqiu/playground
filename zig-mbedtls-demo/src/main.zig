const std = @import("std");
const c = @cImport({
    @cInclude("mbedtls/ctr_drbg.h");
    @cInclude("mbedtls/entropy.h");
    @cInclude("mbedtls/error.h");
    @cInclude("mbedtls/net_sockets.h");
    @cInclude("mbedtls/ssl.h");
    @cInclude("psa/crypto.h");
});

const server_name = "httpbin.org";
const server_port = "443";
const req_path = "/get";

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Memory leaked!");
    const allocator = gpa.allocator();

    const status = c.psa_crypto_init();
    if (status != c.PSA_SUCCESS) {
        std.log.err("psa_crypto_init failed: {d}", .{status});
        return error.PsaInitFailed;
    }

    var res: c_int = undefined;

    var entropy: c.mbedtls_entropy_context = undefined;
    c.mbedtls_entropy_init(&entropy);
    defer c.mbedtls_entropy_free(&entropy);

    var ctr_drbg: c.mbedtls_ctr_drbg_context = undefined;
    c.mbedtls_ctr_drbg_init(&ctr_drbg);
    defer c.mbedtls_ctr_drbg_free(&ctr_drbg);

    res = c.mbedtls_ctr_drbg_seed(&ctr_drbg, c.mbedtls_entropy_func, &entropy, null, 0);
    if (res != 0) {
        logMbedtlsError(res);
        return error.SeedFailed;
    }

    var cacert: c.mbedtls_x509_crt = undefined;
    c.mbedtls_x509_crt_init(&cacert);
    defer c.mbedtls_x509_crt_free(&cacert);

    var bundle: std.crypto.Certificate.Bundle = .{};
    defer bundle.deinit(allocator);
    try bundle.rescan(allocator);
    var iter = bundle.map.iterator();
    while (iter.next()) |entry| {
        const der = try std.crypto.Certificate.der.Element.parse(bundle.bytes.items, entry.value_ptr.*);
        const cert = bundle.bytes.items[entry.value_ptr.*..der.slice.end];
        res = c.mbedtls_x509_crt_parse_der_nocopy(&cacert, cert.ptr, cert.len);
        if (res != 0) {
            logMbedtlsError(res);
        }
    }

    var conf: c.mbedtls_ssl_config = undefined;
    c.mbedtls_ssl_config_init(&conf);
    defer c.mbedtls_ssl_config_free(&conf);

    res = c.mbedtls_ssl_config_defaults(
        &conf,
        c.MBEDTLS_SSL_IS_CLIENT,
        c.MBEDTLS_SSL_TRANSPORT_STREAM,
        c.MBEDTLS_SSL_PRESET_DEFAULT,
    );
    if (res != 0) {
        logMbedtlsError(res);
        return error.CannotInitSslConfig;
    }
    c.mbedtls_ssl_conf_authmode(&conf, c.MBEDTLS_SSL_VERIFY_OPTIONAL);
    c.mbedtls_ssl_conf_ca_chain(&conf, &cacert, null);
    c.mbedtls_ssl_conf_rng(&conf, c.mbedtls_ctr_drbg_random, &ctr_drbg);

    std.log.info("Connecting to server", .{});

    var net_ctx: c.mbedtls_net_context = undefined;
    c.mbedtls_net_init(&net_ctx);
    defer c.mbedtls_net_free(&net_ctx);

    res = c.mbedtls_net_connect(&net_ctx, server_name, server_port, c.MBEDTLS_NET_PROTO_TCP);
    if (res != 0) {
        logMbedtlsError(res);
        return error.CannotConnect;
    }

    var ssl: c.mbedtls_ssl_context = undefined;
    c.mbedtls_ssl_init(&ssl);
    defer c.mbedtls_ssl_free(&ssl);

    res = c.mbedtls_ssl_setup(&ssl, &conf);
    if (res != 0) {
        logMbedtlsError(res);
        return error.SslSetupFailed;
    }
    res = c.mbedtls_ssl_set_hostname(&ssl, server_name);
    if (res != 0) {
        logMbedtlsError(res);
        return error.SetHostnameFailed;
    }

    c.mbedtls_ssl_set_bio(&ssl, &net_ctx, c.mbedtls_net_send, c.mbedtls_net_recv, null);

    std.log.info("Performing SSL/TLS handshake", .{});

    while (true) switch (c.mbedtls_ssl_handshake(&ssl)) {
        0 => break,
        c.MBEDTLS_ERR_SSL_WANT_READ, c.MBEDTLS_ERR_SSL_WANT_WRITE => continue,
        else => |v| {
            logMbedtlsError(v);
            return error.HandshakeError;
        },
    };

    const flags = c.mbedtls_ssl_get_verify_result(&ssl);
    if (flags != 0) {
        var vrfy_buf: [512]u8 = undefined;
        _ = c.mbedtls_x509_crt_verify_info(&vrfy_buf, vrfy_buf.len, "  ! ", flags);
        const view: [*:0]const u8 = @ptrCast(&vrfy_buf);
        std.log.warn("{s}", .{view});
    } else {
        std.log.debug("Verification OK", .{});
    }

    defer _ = c.mbedtls_ssl_close_notify(&ssl);

    std.log.info("Sending request", .{});

    const get_req = try std.fmt.allocPrint(
        allocator,
        "GET {s} HTTP/1.1\r\nHost: {s}\r\nConnection: Close\r\n\r\n\r\n",
        .{ req_path, server_name },
    );
    defer allocator.free(get_req);

    var written: usize = 0;
    while (true) {
        const to_send = get_req[written..];
        res = c.mbedtls_ssl_write(&ssl, to_send.ptr, to_send.len);

        if (res == to_send.len) break;
        if (res > 0) {
            written += @intCast(res);
            continue;
        }
        if (res == c.MBEDTLS_ERR_SSL_WANT_READ or res == c.MBEDTLS_ERR_SSL_WANT_WRITE) {
            continue;
        }
        logMbedtlsError(res);
        return error.SslWriteError;
    }

    std.log.info("Receiving response", .{});

    var response = std.ArrayList(u8).init(allocator);
    defer response.deinit();

    var recv_buffer: [1024]u8 = undefined;
    while (true) {
        res = c.mbedtls_ssl_read(&ssl, &recv_buffer, recv_buffer.len);

        if (res == 0) break;
        if (res > 0) {
            try response.appendSlice(recv_buffer[0..@intCast(res)]);
            continue;
        }
        if (res == c.MBEDTLS_ERR_SSL_WANT_READ or res == c.MBEDTLS_ERR_SSL_WANT_WRITE) {
            continue;
        }
        logMbedtlsError(res);
        return error.SslReadError;
    }

    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}\n", .{response.items});
}

fn logMbedtlsError(code: c_int) void {
    var buffer: [256]u8 = undefined;
    c.mbedtls_strerror(code, &buffer, buffer.len);
    const view: [*:0]const u8 = @ptrCast(&buffer);
    std.log.err("Mbedtls error {d}: {s}", .{ code, view });
}
