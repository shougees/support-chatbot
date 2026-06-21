require "json"
require "net/http"

module SupportBot
  class OpenaiHttpClient
    RESPONSES_URI = URI("https://api.openai.com/v1/responses")

    def post_response(api_key:, payload:)
      request = Net::HTTP::Post.new(RESPONSES_URI)
      request["Authorization"] = "Bearer #{api_key}"
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(RESPONSES_URI.hostname, RESPONSES_URI.port, use_ssl: true) do |http|
        http.request(request)
      end

      JSON.parse(response.body).merge("_http_status" => response.code.to_i)
    end
  end
end
