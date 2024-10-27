require "async/websocket/adapters/rails"
require "async/http/endpoint"
require "async/websocket/client"
require "async/barrier"

class WebsocketsController < ApplicationController
  # WebSocket clients may not send CSRF tokens, so disable this check.
  skip_before_action :verify_authenticity_token, only: [:connect]

  # URL for connecting to OpenAI WebSocket
  OPENAI_WS_URL = "wss://api.openai.com/v1/realtime?model=gpt-4o-realtime-preview-2024-10-01"

  def connect
    # Open a WebSocket connection with the client
    self.response = Async::WebSocket::Adapters::Rails.open(request) do |client_connection|
      setup_bridge(client_connection)
    end
  end

  private

  # Setup a persistent connection bridge between the client and OpenAI
  def setup_bridge(client_connection)
    # Define the endpoint with HTTP/1.1 protocol
    endpoint = Async::HTTP::Endpoint.parse(
      OPENAI_WS_URL, 
      alpn_protocols: Async::HTTP::Protocol::HTTP11.names
    )

    # Headers required for authentication with OpenAI
    headers = {
      "Authorization" => "Bearer #{fetch_openai_api_key}",
      "OpenAI-Beta" => "realtime=v1"
    }

    barrier = Async::Barrier.new

    begin
      # Establish connection to OpenAI WebSocket
      openai_connection = Async::WebSocket::Client.connect(endpoint, headers: headers)
      Rails.logger.info "Connected to OpenAI for client #{client_connection.object_id}"
      
      # Notify client that the bridge is established
      client_connection.write("Connected to OpenAI")

      # Start handling communication in parallel tasks
      barrier.async { handle_client_to_openai(client_connection, openai_connection) }
      barrier.async { handle_openai_to_client(client_connection, openai_connection) }

      # Wait for both tasks to complete
      barrier.wait
    rescue => e
      Rails.logger.error "Error setting up bridge: #{e.message}"
    ensure
      # Ensure all tasks are stopped and connections are closed
      barrier.stop
      safely_close_connections(client_connection, openai_connection)
    end
  end

  # Handle messages from the client and forward them to OpenAI
  def handle_client_to_openai(client_connection, openai_connection)
    begin
      # Continue reading and processing messages while they exist
      while (client_message = client_connection.read)
        Rails.logger.info "[Client #{client_connection.object_id}] Received: #{client_message.inspect}"

        # Prepare and send the message to OpenAI
        formatted_message = format_message_for_openai(client_message)
        openai_connection.write(Protocol::WebSocket::TextMessage.generate(formatted_message))
        openai_connection.flush
      end
    rescue => e
      Rails.logger.error "[Client #{client_connection.object_id}] Error handling client message: #{e.message}"
    ensure
      safely_close_connections(client_connection, openai_connection)
    end
  end

  # Handle messages from OpenAI and forward them to the client
  def handle_openai_to_client(client_connection, openai_connection)
    begin
      # Continue reading and processing messages while they exist
      while (openai_message = openai_connection.read)
        Rails.logger.info "[Client #{client_connection.object_id}] OpenAI message: #{openai_message.inspect}"

        # Forward the message to the client
        client_connection.write(openai_message)
        client_connection.flush
      end
    rescue => e
      Rails.logger.error "[Client #{client_connection.object_id}] Error handling OpenAI message: #{e.message}"
    ensure
      safely_close_connections(client_connection, openai_connection)
    end
  end

  # Format the message to be sent to OpenAI, ensuring valid instructions
  def format_message_for_openai(client_message)
    instructions = client_message.buffer.strip
    raise "Instructions cannot be empty" if instructions.empty?

    {
      type: "response.create",
      response: {
        modalities: ["text"],
        instructions: instructions
      }
    }
  end

  # Close connections safely, ensuring they exist and are not already closed
  def safely_close_connections(client_connection, openai_connection)
    Rails.logger.info "[Client #{client_connection.object_id}] Closing connections"
    
    close_connection(client_connection)
    close_connection(openai_connection)
  end

  # Helper method to close a connection if it exists and is open
  def close_connection(connection)
    return unless connection && !connection.closed?

    connection.close
  rescue => e
    Rails.logger.error "Error closing connection: #{e.message}"
  end

  # Fetch OpenAI API key from environment variables
  def fetch_openai_api_key
    ENV.fetch("OPENAI_API_KEY") { raise "OPENAI_API_KEY is not set" }
  end
end
