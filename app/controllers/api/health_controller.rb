module Api
  class HealthController < ApplicationController
    def show
      render json: {
        status: "ok",
        timestamp: Time.current,
        version: "1.0.0"
      }
    end
  end
end
