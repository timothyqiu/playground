#include "http.hpp"
#include <stdexcept>
#include <ixwebsocket/IXHttpClient.h>

std::string http_get(std::string const& url)
{
    ix::HttpClient client;

    // IXWebSocket only properly loads certs on Windows
    ix::SocketTLSOptions tls_options;
    tls_options.caFile = "NONE";
    client.setTLSOptions(tls_options);

    auto const resp = client.get(url, client.createRequest());

    if (resp->errorCode != ix::HttpErrorCode::Ok) {
        throw std::runtime_error{resp->errorMsg};
    }

    return resp->body;
}
