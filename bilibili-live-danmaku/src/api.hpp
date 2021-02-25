#ifndef BLD_API_HPP_
#define BLD_API_HPP_

#include <cstdint>
#include <functional>
#include <string>
#include <vector>

namespace api {

// 直播状态
enum class LiveStatus
{
    Live = 1,       // 直播中
    Preparing = 2   // 准备中（包括轮播）
};

// 直播间信息
struct WebRoomInfo
{
    int room_id;            // 房间号
    std::string title;      // 房间标题
    LiveStatus live_status; // 直播状态

    int uid;                // 主播号
    std::string uname;      // 主播名

    int area_id;            // 分区号
    std::string area_name;  // 分区名

    // 支持短号
    explicit WebRoomInfo(int id);
};

// 弹幕系统
namespace danmaku {

// 直播服务器信息
struct LiveServer
{
    std::string host;
    int ws_port;
    int wss_port;
};

// 授权
struct Auth
{
    std::vector<LiveServer> servers;
    std::string token;

    // servers 一定非空
    explicit Auth(int room_id);
};

// 协议
enum class Protocol
{
    Text = 0,       // 负载为纯文本（如 JSON）
    Binary = 1,     // 负载为二进制
    Compressed = 2, // 负载为 DEFLATE 压缩后的数据
};

// 指令
enum class Operation
{
    // 请求
    HeartbeatReq = 2,   // 心跳（房间人气）
    AuthReq = 7,        // 鉴权

    // 响应
    HeartbeatResp = 3,  // 心跳（房间人气）
    AuthResp = 8,       // 鉴权
    Message = 5,        // 一般消息
};

// 数据包
struct Packet
{
    Protocol protocol;
    Operation operation;

    // 负载
    std::uint8_t const *payload;
    std::size_t payload_size;

    // 构造心跳请求包
    static auto make_heartbeat_req() -> Packet;
    // 构造鉴权请求包
    static auto make_auth_req(int room_id, std::string const& token) -> Packet;

    // 反序列化
    // 把原始数据切割、解析、解压成若干个包，得到的数据包不是 Text 就是 Binary 的
    static auto load(void const *data, std::size_t size,
                     std::function<void(Packet const&)> packet_callback) -> void;

    // 序列化
    auto dump() const -> std::vector<std::uint8_t>;
};

}  // namespace danmaku

}  // namespace api

#endif  // BLD_API_HPP_
