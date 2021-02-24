#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstdlib>
#include <string>
#include <stdexcept>
#include <thread>

#include <fmt/core.h>
#include <ixwebsocket/IXHttpClient.h>
#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocket.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include "buffer.hpp"
#include "inflator.hpp"
#include "options.hpp"

using json = nlohmann::json;

enum class Operation: int
{
    Heartbeat = 2,
    HeartbeatResponse = 3,
    Message = 5,
    Auth = 7,
    AuthResponse = 8,
};

enum class ProtocolVersion: int
{
    Text = 0,
    Binary = 1,
    Compressed = 2,
};

struct LiveServer
{
    std::string host;
    int ws_port;
    int wss_port;
};

struct LiveConfig
{
    std::vector<LiveServer> servers;
    std::string token;

    explicit LiveConfig(int room_id)
    {
        ix::HttpClient client;

        // IXWebSocket only properly loads certs on Windows
        ix::SocketTLSOptions tls_options;
        tls_options.caFile = "NONE";
        client.setTLSOptions(tls_options);

        auto const url = fmt::format(
            "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?id={}",
            room_id
        );
        auto resp = client.get(url, client.createRequest());

        if (resp->errorCode != ix::HttpErrorCode::Ok) {
            throw std::runtime_error{resp->errorMsg};
        }

        spdlog::debug("getDanmuInfo: {}", resp->body);

        auto const data = json::parse(resp->body)["data"];

        this->token = data["token"];

        auto const& host_list = data["host_list"];
        this->servers.reserve(host_list.size());

        for (auto const& info : host_list) {
            this->servers.emplace_back(LiveServer{
                info["host"], info["ws_port"].get<int>(), info["wss_port"].get<int>()
            });
        }
    }
};

static bool interrupted;

static void sigint_handler(int)
{
    interrupted = true;
}

static void handle_message(Options const& options, json const& body)
{
    auto const cmd = body["cmd"].get<std::string>();

    // TODO: map

    /*  */ if (cmd == "INTERACT_WORD") {
        if (options.show_entering) {
            spdlog::info("[Enter] {}", body["data"]["uname"]);
        }
    } else if (cmd == "DANMU_MSG") {
        spdlog::info("[Danmaku] {}: {}", body["info"][2][1], body["info"][1]);
    } else if (cmd == "SEND_GIFT") {
        spdlog::info("[Gift] {} sent {} x{}",
                     body["data"]["uname"], body["data"]["giftName"], body["data"]["num"].get<int>());
    } else if (cmd == "NOTICE_MSG") {
        spdlog::info("[NOTICE] (type {}) {}",
                     body["msg_type"].get<int>(),
                     (body["real_roomid"] == options.room_id) ? body["msg_self"] : body["msg_common"]);
    } else {
        spdlog::debug("Message: {}", body.dump());
    }
}

static void handle_data(Options const& options, void const *data, std::size_t size)
{
    ReadBuffer chunk_buffer{data, size};

    while (chunk_buffer.size() > 0) {
        auto buffer = chunk_buffer.pull_buffer(chunk_buffer.peek_u32());

        auto const packet_size = buffer.pull_u32();
        auto const header_size = buffer.pull_u16();
        auto const protocol_version = static_cast<ProtocolVersion>(buffer.pull_u16());
        auto const operation = static_cast<Operation>(buffer.pull_u32());
        buffer.pull_u32();

        if (protocol_version == ProtocolVersion::Compressed) {
            auto const decompressed = decompress(buffer.begin(), packet_size - header_size);
            spdlog::trace("Decompressed {} bytes -> {} bytes", buffer.size(), decompressed.size());
            handle_data(options, decompressed.data(), decompressed.size());
        } else {
            spdlog::trace("Packet ({} bytes, {} header, {} version, {} operation)", packet_size, header_size, protocol_version, operation);

            switch (operation) {
            case Operation::AuthResponse:
                {
                    auto const code = json::parse(buffer.begin(), buffer.end())["code"].get<int>();
                    spdlog::debug("Auth response: {}", code);
                    if (code != 0) {
                        throw std::runtime_error{fmt::format("auth failed: {}", buffer.peek_string())};
                    }
                }
                break;

            case Operation::Message:
                handle_message(options, json::parse(buffer.begin(), buffer.end()));
                break;

            case Operation::HeartbeatResponse:
                spdlog::info("Popularity: {}", buffer.pull_u32());
                break;

            case Operation::Auth:
            case Operation::Heartbeat:
                spdlog::warn("Unhandled operation: {}", operation);
                break;
            }
        }
    }
}

int main(int argc, char *argv[])
try {
    Options options{argc, argv};

    ix::initNetSystem();

    std::signal(SIGINT, sigint_handler);

    spdlog::set_level(spdlog::level::debug);
    spdlog::info("Bilibili Live Danmaku");

    LiveConfig config{options.room_id};

    ix::WebSocket web_socket;
    // web_socket.disableAutomaticReconnection();

    // IXWebSocket only properly loads certs on Windows
    ix::SocketTLSOptions tls_options;
    tls_options.caFile = "NONE";
    web_socket.setTLSOptions(tls_options);

    auto const& server = config.servers.front();
    auto const url = fmt::format("ws://{}:{}/sub", server.host, server.ws_port);

    spdlog::info("Connecting to {}", url);
    web_socket.setUrl(url);

    web_socket.setOnMessageCallback([&](ix::WebSocketMessagePtr const& msg) {
        switch (msg->type) {
        case ix::WebSocketMessageType::Open:
            spdlog::info("Connection established");
            {
                spdlog::info("Entering room {}", options.room_id);

                auto const header_size = 4 + 2 + 2 + 4 + 4;
                auto const body = json{
                    { "uid", 0 },
                    { "roomid", options.room_id },
                    { "protover", 2 },
                    { "platform", "web" },
                    { "clientver", "2.6.27" },
                    { "type", 2 },
                    { "key", config.token },
                }.dump();

                WriteBuffer buffer{128};
                buffer.push_u32(header_size + body.size());
                buffer.push_u16(header_size);
                buffer.push_u16(static_cast<int>(ProtocolVersion::Text));
                buffer.push_u32(static_cast<int>(Operation::Auth));
                buffer.push_u32(1);
                buffer.push_data(body.data(), body.size());

                web_socket.sendBinary({buffer.begin(), buffer.end()});
            }
            break;

        case ix::WebSocketMessageType::Close:
            spdlog::warn("Connection closed: {} {}", msg->closeInfo.code, msg->closeInfo.reason);
            break;

        case ix::WebSocketMessageType::Error:
            spdlog::error("Error: {}", msg->errorInfo.reason);
            break;

        case ix::WebSocketMessageType::Message:
            if (msg->binary) {
                try {
                    handle_data(options, msg->str.data(), msg->str.size());
                }
                catch (std::exception const& e) {
                    spdlog::error("Unhandled exception when handling data: {}", e.what());
                }
            } else {
                spdlog::warn("Unexpected text message: {}", msg->str);
            }
            break;

        case ix::WebSocketMessageType::Ping:
        case ix::WebSocketMessageType::Pong:
        case ix::WebSocketMessageType::Fragment:
            spdlog::warn("Unhandled message type: {}", msg->type);
            break;
        }
    });

    web_socket.start();

    unsigned int raw_counter = 0;
    while (!interrupted) {
        std::this_thread::sleep_for(std::chrono::seconds{1});

        if (++raw_counter % 30 == 0 && web_socket.getReadyState() == ix::ReadyState::Open) {
            spdlog::debug("Sending heartbeat");

            auto const header_size = 4 + 2 + 2 + 4 + 4;
            std::string const payload{"[object Object]"};

            WriteBuffer buffer{64};
            buffer.push_u32(header_size + payload.size());
            buffer.push_u16(header_size);
            buffer.push_u16(static_cast<int>(ProtocolVersion::Text));
            buffer.push_u32(static_cast<int>(Operation::Heartbeat));
            buffer.push_u32(1);
            buffer.push_data(payload.data(), payload.size());

            web_socket.sendBinary({buffer.begin(), buffer.end()});
        }
    }

    web_socket.stop();
}
catch (std::exception const& e) {
    spdlog::error("Unhandled exception: {}", e.what());
}
