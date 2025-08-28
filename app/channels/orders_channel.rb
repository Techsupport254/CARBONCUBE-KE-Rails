# app/channels/orders_channel.rb
class OrdersChannel < ApplicationCable::Channel
  def subscribed
    stream_from "orders_channel"
  end

  def unsubscribed
    # Any cleanup needed when channel is unsubscribed
  end
end
