module Operator
  class AnalyticsController < ApplicationController
    def show
      @analytics = SupportAnalyticsSnapshot.call
    end
  end
end
