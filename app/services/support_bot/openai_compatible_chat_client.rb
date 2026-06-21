require "json"
require "net/http"

module SupportBot
  class OpenaiCompatibleChatClient
    def post_chat_completion(api_key:, base_url:, payload:)
      uri = chat_completions_uri(base_url)
      request = Net::HTTP::Post.new(uri)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == "https") do |http|
        http.request(request)
      end

      response_body = response.body.present? ? response.body : "{}"
      JSON.parse(response_body).merge("_http_status" => response.code.to_i)
    end

    private

    def chat_completions_uri(base_url)
      normalized_base_url = base_url.to_s.chomp("/")
      endpoint = normalized_base_url.end_with?("/chat/completions") ? normalized_base_url : "#{normalized_base_url}/chat/completions"

      URI(endpoint)
    end
  end
end
