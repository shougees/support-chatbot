require "json"
require "net/http"

module SupportBot
  # Single HTTP transport for OpenAI-compatible JSON endpoints. This replaces
  # the two near-identical Net::HTTP clients (`OpenaiHttpClient` and
  # `OpenaiCompatibleChatClient`) that only differed in which URL they posted
  # to. The caller supplies the fully-resolved URL.
  class HttpClient
    def post_json(url:, api_key:, payload:)
      uri = url.is_a?(URI) ? url : URI(url)

      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      body = response.body.present? ? response.body : "{}"
      parsed = JSON.parse(body)
      # Some gateways return a valid-but-non-object JSON body (array/scalar).
      # Normalize so callers can always rely on a Hash carrying _http_status.
      parsed = { "data" => parsed } unless parsed.is_a?(Hash)
      parsed.merge("_http_status" => response.code.to_i)
    end
  end
end
