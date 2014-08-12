# Handle HTTP response status codes
#
module Podio
  module Middleware
    class ErrorResponse < Faraday::Response::Middleware
      def on_complete(env)
        # Store the x-rates in the client as to keep an eye on the limits during development
        # not be merged into Podio dev.
        if env[:response_headers]['x-rate-limit-remaining'].present? and env[:response_headers]['x-rate-limit-limit'].present?
          if(env[:response_headers]['x-rate-limit-limit'].to_i < 5000)
            Podio::client.rate_limited_max = env[:response_headers]['x-rate-limit-limit']
            Podio::client.rate_limited_current =  env[:response_headers]['x-rate-limit-remaining']
          else
            Podio::client.no_rate_limited_max = env[:response_headers]['x-rate-limit-limit']
            Podio::client.no_rate_limited_current =  env[:response_headers]['x-rate-limit-remaining']
          end
        end

        error_class = case env[:status]

          when 200, 204
            # pass
          when 400
            case env[:body]['error']
            when 'invalid_grant'
              InvalidGrantError
            else
              BadRequestError
            end
          when 401
            if env[:body]['error_description'] =~ /expired_token/
              TokenExpired
            else
              AuthorizationError
            end
          when 402
            PaymentRequiredError
          when 403
            if env[:body]['error'] == 'requestable_forbidden'
              RequestableAuthorizationError
            else
              AuthorizationError
            end
          when 404
            NotFoundError
          when 409
            ConflictError
          when 410
            GoneError
          when 420
            RateLimitError
          when 500
            ServerError
          when 502, 503
            UnavailableError
          else
            # anything else is something unexpected, so it
            ServerError
        end

        if error_class
          raise error_class.new(env[:body], env[:status], env[:url])
        end
      end
    end
  end
end
