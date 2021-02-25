#include <chrono>
#include <csignal>
#include <cstdint>
#include <cstdlib>
#include <functional>
#include <map>
#include <string>
#include <stdexcept>
#include <thread>

#include <fmt/core.h>
#include <ixwebsocket/IXNetSystem.h>
#include <ixwebsocket/IXWebSocket.h>
#include <nlohmann/json.hpp>
#include <spdlog/spdlog.h>

#include "buffer.hpp"
#include "options.hpp"
#include "api.hpp"

using json = nlohmann::json;
using api::danmaku::Packet;
using api::danmaku::Operation;

std::map<std::string, std::function<void(nlohmann::json const& body)>> g_command_handlers;

static bool interrupted;

static void sigint_handler(int)
{
    interrupted = true;
}

static void handle_data(void const *data, std::size_t size)
try {
    Packet::load(data, size, [&](Packet const& packet) {
        switch (packet.operation) {
        case Operation::AuthResp:
            {
                auto const code = json::parse(packet.payload, packet.payload + packet.payload_size)["code"].get<int>();
                if (code != 0) {
                    auto const payload = std::string{packet.payload, packet.payload + packet.payload_size};
                    throw std::runtime_error{fmt::format("auth failed: {}", payload)};
                }
            }
            break;

        case Operation::HeartbeatResp:
            {
                auto const popularity = ReadBuffer{packet.payload, packet.payload_size}.peek_u32();
                spdlog::info("Room popularity: {}", popularity);
            }
            break;

        case Operation::Message:
            try {
                auto const body = json::parse(packet.payload, packet.payload + packet.payload_size);
                auto const cmd = body["cmd"].get<std::string>();
                auto const iter = g_command_handlers.find(cmd);
                if (iter == std::end(g_command_handlers)) {
                    spdlog::debug("Unknown message: {}", body.dump());
                } else {
                    iter->second(body);
                }
            }
            catch (json::exception const& e) {
                auto const payload = std::string{packet.payload, packet.payload + packet.payload_size};
                spdlog::debug("Error handling JSON: {}", payload);
                throw;
            }
            break;

        case Operation::AuthReq:
        case Operation::HeartbeatReq:
            spdlog::warn("Unexpected operation: {}", packet.operation);
            break;
        }
    });
}
catch (std::exception const& e) {
    spdlog::error("Unhandled exception when handling data: {}", e.what());
}

int main(int argc, char *argv[])
try {
    ix::initNetSystem();

    Options const options{argc, argv};

    spdlog::set_level(options.verbose ? spdlog::level::debug : spdlog::level::info);

    api::WebRoomInfo const room_info{options.room_id};
    spdlog::info("({}) {} - {}",
                 (room_info.live_status == api::LiveStatus::Live ? "直播中" : "准备中"),
                 room_info.uname, room_info.title);

    // ----------------
    // 弹幕命令处理函数
    // ----------------
    auto const ignore = [](nlohmann::json const&) {};

    g_command_handlers["INTERACT_WORD"] = !options.show_entering ? ignore : [](nlohmann::json const& body) {
        // 普通观众进入直播间
        auto const uname = body["data"]["uname"];
        spdlog::info("{} 进入直播间", uname);
    };
    g_command_handlers["LIVE"] = [&](nlohmann::json const& body) {
        // 直播开始
        spdlog::info("直播开始");
        spdlog::debug(body.dump());
    };
    g_command_handlers["PREPARING"] = [&](nlohmann::json const& body) {
        // 直播结束
        spdlog::info("直播结束");
        spdlog::debug(body.dump());
    };
    g_command_handlers["ENTRY_EFFECT"] = [&](nlohmann::json const& body) {
        // 特殊用户进入直播间
        spdlog::info(body["data"]["copy_writing"]);
    };
    g_command_handlers["DANMU_MSG"] = [&](nlohmann::json const& body) {
        // 弹幕
        auto const name = body["info"][2][1];
        auto const text = body["info"][1];
        spdlog::info("{}: {}", name, text);
    };
    g_command_handlers["ONLINE_RANK_V2"] = [&](nlohmann::json const& body) {
        // 高能榜
        std::string message{"高能榜"};
        for (auto const& entry : body["data"]["list"]) {
            auto const rank = entry["rank"].get<int>();
            auto const score = entry["score"].get<std::string>();
            auto const name = entry["uname"].get<std::string>();
            message += fmt::format(" #{} {}({}) ", rank, name, score);
        }
        spdlog::info(message);
    };
    g_command_handlers["ONLINE_RANK_COUNT"] = [&](nlohmann::json const& body) {
        // 高能榜数量
        spdlog::info("高能榜数量更新为 {}", body["data"]["count"].get<int>());
    };
    g_command_handlers["ROOM_REAL_TIME_MESSAGE_UPDATE"] = [&](nlohmann::json const& body) {
        // 粉丝数量等
        spdlog::info("粉丝数量更新为 {}", body["data"]["fans"].get<int>());
    };
    g_command_handlers["NOTICE_MSG"] = [&](nlohmann::json const& body) {
        // 通知
        auto const real_room_id = body["real_roomid"].get<int>();
        spdlog::info("通知 {}", (room_info.room_id == real_room_id) ? body["msg_self"] : body["msg_common"]);
    };
    g_command_handlers["SEND_GIFT"] = [](nlohmann::json const& body) {
        // 礼物
        auto const& data = body["data"];

        auto const action = data.value("action", "赠送");
        auto const uname = data["uname"].get<std::string>();
        auto const gift_name = data["giftName"].get<std::string>();
        auto const num = data["num"].get<int>();

        spdlog::info("{} {} {}x{}", uname, action, gift_name, num);
    };
    g_command_handlers["COMBO_SEND"] = [](nlohmann::json const& body) {
        // 礼物连击
        auto const& data = body["data"];

        auto const action = data.value("action", "赠送");
        auto const uname = data["uname"].get<std::string>();
        auto const gift_name = data["gift_name"].get<std::string>();
        auto const total_num = data["total_num"].get<int>();
        auto const combo_num = data["batch_combo_num"].get<int>();

        spdlog::info("{} {} {} 共{}个, {}连击", uname, action, gift_name, total_num, combo_num);
    };

    // 人气PK（老版本）
    g_command_handlers["PK_BATTLE_PRE"] = ignore;
    g_command_handlers["PK_BATTLE_START"] = ignore;
    g_command_handlers["PK_BATTLE_PROCESS"] = ignore;
    g_command_handlers["PK_BATTLE_SETTLE"] = ignore;

    // 人气PK
    g_command_handlers["PK_BATTLE_PRE_NEW"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<int>();
        auto const room_id = body["data"]["room_id"].get<int>();
        auto const uname = body["data"]["uname"].get<std::string>();
        spdlog::info("人气PK {} 准备 - {}({})", id, uname, room_id);
    };
    g_command_handlers["PK_BATTLE_START_NEW"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<int>();
        spdlog::info("人气PK {} 开始", id);
        spdlog::debug(body.dump());
    };
    g_command_handlers["PK_BATTLE_PROCESS_NEW"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<int>();

        auto const init_uname = body["data"]["init_info"]["best_uname"].get<std::string>();
        auto const init_votes = body["data"]["init_info"]["votes"].get<int>();
        auto const init_room_id = body["data"]["init_info"]["room_id"].get<int>();

        auto const match_uname = body["data"]["match_info"]["best_uname"].get<std::string>();
        auto const match_votes = body["data"]["match_info"]["votes"].get<int>();
        auto const match_room_id = body["data"]["match_info"]["room_id"].get<int>();

        spdlog::info("人气PK {} 进度 - {} {}({}) VS {}({}) {}", id,
                     init_room_id, init_uname, init_votes,
                     match_uname, match_votes, match_room_id);
    };
    g_command_handlers["PK_BATTLE_END"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<std::string>();  // 太傻了，为什么只有这里是字符串

        auto const init_uname = body["data"]["init_info"]["best_uname"].get<std::string>();
        auto const init_votes = body["data"]["init_info"]["votes"].get<int>();
        auto const init_room_id = body["data"]["init_info"]["room_id"].get<int>();

        auto const match_uname = body["data"]["match_info"]["best_uname"].get<std::string>();
        auto const match_votes = body["data"]["match_info"]["votes"].get<int>();
        auto const match_room_id = body["data"]["match_info"]["room_id"].get<int>();

        spdlog::info("人气PK {} 结束 - {} {}({}) VS {}({}) {}", id,
                     init_room_id, init_uname, init_votes,
                     match_uname, match_votes, match_room_id);
    };
    g_command_handlers["PK_BATTLE_SETTLE_USER"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<int>();

        auto const winner_room_id = body["data"]["winner"]["room_id"].get<int>();
        auto const winner_uname = body["data"]["winner"]["uname"];

        spdlog::info("人气PK {} 用户结果 - {}({}) 胜出", id, winner_uname, winner_room_id);
    };
    g_command_handlers["PK_BATTLE_SETTLE_V2"] = [&](nlohmann::json const& body) {
        auto const id = body["pk_id"].get<int>();

        std::string message{"助力榜"};
        for (auto const& entry : body["data"]["assist_list"]) {
            message += fmt::format(" {}({})", entry["uname"], entry["score"].get<int>());
        }

        spdlog::info("人气PK {} 结果 - {}", id, message);
    };

    // 开始连接弹幕系统
    api::danmaku::Auth const auth{room_info.room_id};

    ix::WebSocket web_socket;
    {
        if (!options.reconnect) {
            web_socket.disableAutomaticReconnection();
        }

        // IXWebSocket only properly loads certs on Windows
        ix::SocketTLSOptions tls_options;
        tls_options.caFile = "NONE";
        web_socket.setTLSOptions(tls_options);
    }

    auto const& server = auth.servers.front();
    auto const url = fmt::format("ws://{}:{}/sub", server.host, server.ws_port);
    spdlog::debug("Connecting to {}", url);
    web_socket.setUrl(url);

    web_socket.setOnMessageCallback([&](ix::WebSocketMessagePtr const& msg) {
        switch (msg->type) {
        case ix::WebSocketMessageType::Open:
            spdlog::info("Connection established");
            {
                spdlog::debug("Entering room {}", room_info.room_id);
                auto const packet = Packet::make_auth_req(room_info.room_id, auth.token).dump();
                web_socket.sendBinary({packet.begin(), packet.end()});
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
                handle_data(msg->str.data(), msg->str.size());
            } else {
                spdlog::warn("Unexpected text message: {}", msg->str);
            }
            break;

        case ix::WebSocketMessageType::Ping:
        case ix::WebSocketMessageType::Pong:
        case ix::WebSocketMessageType::Fragment:
            spdlog::warn("Unexpected message type: {}", msg->type);
            break;
        }
    });

    std::signal(SIGINT, sigint_handler);

    web_socket.start();

    unsigned int raw_counter = 0;
    while (!interrupted) {
        std::this_thread::sleep_for(std::chrono::seconds{1});

        if (++raw_counter % 30 == 0 && web_socket.getReadyState() == ix::ReadyState::Open) {
            spdlog::debug("Sending heartbeat");

            auto const packet = Packet::make_heartbeat_req().dump();
            web_socket.sendBinary({packet.begin(), packet.end()});
        }
    }

    web_socket.stop();
}
catch (std::exception const& e) {
    spdlog::error("Unhandled exception: {}", e.what());
}
