#include "api.hpp"
#include "http.hpp"

#include <stdexcept>

#include <fmt/core.h>
#include <nlohmann/json.hpp>

#include "buffer.hpp"
#include "inflator.hpp"


namespace api {

WebRoomInfo::WebRoomInfo(int id)
{
    auto const url = fmt::format(
        "https://api.live.bilibili.com/xlive/web-room/v1/index/getInfoByRoom?room_id={}",
        id
    );
    auto const body = http_get(url);
    auto const json = nlohmann::json::parse(body);

    if (json["code"] != 0) {
        throw std::runtime_error{fmt::format("WebRoomInfo: {}", json["message"])};
    }

    auto const& room_info = json["data"]["room_info"];

    this->room_id = room_info["room_id"];
    this->title = room_info["title"];
    this->live_status = static_cast<LiveStatus>(room_info["live_status"]);

    this->uid = room_info["uid"];
    this->uname = json["data"]["anchor_info"]["base_info"]["uname"];

    this->area_id = room_info["area_id"];
    this->area_name = room_info["area_name"];
};

namespace danmaku {

Auth::Auth(int room_id)
{
    auto const url = fmt::format(
        "https://api.live.bilibili.com/xlive/web-room/v1/index/getDanmuInfo?id={}",
        room_id
    );
    auto const body = http_get(url);
    auto const json = nlohmann::json::parse(body);

    if (json["code"] != 0) {
        throw std::runtime_error{fmt::format("DanmakuAuth: {}", json["message"])};
    }

    auto const& data = json["data"];

    this->token = data["token"];

    auto const& host_list = data["host_list"];
    if (host_list.empty()) {
        throw std::runtime_error{"DanmakuAuth: No live server available"};
    }

    this->servers.reserve(host_list.size());
    for (auto const& info : host_list) {
        this->servers.push_back(LiveServer{
            info["host"], info["ws_port"].get<int>(), info["wss_port"].get<int>()
        });
    }
}

auto Packet::make_heartbeat_req() -> Packet
{
    std::string const payload{"[object Object]"};
    return Packet{
        Protocol::Text,
        Operation::HeartbeatReq,
        reinterpret_cast<std::uint8_t const *>(payload.data()),
        payload.size()
    };
}

auto Packet::make_auth_req(int room_id, std::string const& token) -> Packet
{
    auto const payload = nlohmann::json{
        { "uid", 0 },
        { "roomid", room_id },
        { "protover", 2 },
        { "platform", "web" },
        { "clientver", "2.6.27" },
        { "type", 2 },
        { "key", token },
    }.dump();
    return Packet{
        Protocol::Text,
        Operation::AuthReq,
        reinterpret_cast<std::uint8_t const *>(payload.data()),
        payload.size()
    };
}

auto Packet::load(void const *data, std::size_t size,
                  std::function<void(Packet const&)> packet_callback) -> void
{
    ReadBuffer chunk_buffer{data, size};

    while (chunk_buffer.size() > 0) {
        auto buffer = chunk_buffer.pull_buffer(chunk_buffer.peek_u32());

        buffer.pull_u32();
        buffer.pull_u16();
        auto const protocol = static_cast<Protocol>(buffer.pull_u16());
        auto const operation = static_cast<Operation>(buffer.pull_u32());
        buffer.pull_u32();

        if (protocol == Protocol::Compressed) {
            auto const inflated = decompress(buffer.begin(), buffer.size());
            load(inflated.data(), inflated.size(), packet_callback);
        } else {
            packet_callback(Packet{protocol, operation, buffer.begin(), buffer.size()});
        }
    }
}

auto Packet::dump() const -> std::vector<std::uint8_t>
{
    auto const header_size = 4 + 2 + 2 + 4 + 4;

    WriteBuffer buffer{256};
    buffer.push_u32(header_size + this->payload_size);
    buffer.push_u16(header_size);
    buffer.push_u16(static_cast<unsigned>(this->protocol));
    buffer.push_u32(static_cast<unsigned>(this->operation));
    buffer.push_u32(1);
    buffer.push_data(this->payload, this->payload_size);
return buffer.done();
}

}  // namespace danmaku

}  // namespace api
