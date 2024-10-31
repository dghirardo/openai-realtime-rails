import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input", "chat"];

  connect() {
    this.initializeWebSocket();
  }

  disconnect() {
    this.closeWebSocket();
  }

  // Initialize the WebSocket connection
  initializeWebSocket() {
    const websocketUrl = `ws://${window.location.host}/websockets/connect`;
    this.websocket = new WebSocket(websocketUrl);

    this.websocket.onopen = this.handleWebSocketOpen;
    this.websocket.onmessage = (event) => this.handleWebSocketMessage(event);
    this.websocket.onerror = this.handleWebSocketError;
    this.websocket.onclose = this.handleWebSocketClose;
  }

  // Close the WebSocket connection
  closeWebSocket() {
    if (this.websocket) {
      this.websocket.close();
      this.websocket = null;
    }
  }

  // Handler for the WebSocket 'open' event
  handleWebSocketOpen = () => {
    console.log("WebSocket connection opened");
  };

  // Handler for incoming messages from the server
  handleWebSocketMessage(event) {
    const data = JSON.parse(event.data);
    const messageElement = document.getElementById(data.item_id);

    if (messageElement) {
      this.processIncomingMessage(data, messageElement);
    } else {
      this.displayMessage({
        message: data.delta,
        id: data.item_id,
        sender: "assistant"
      });
    }
  }

  // Handler for the WebSocket 'error' event
  handleWebSocketError = (error) => {
    console.error("WebSocket error:", error);
  };

  // Handler for the WebSocket 'close' event
  handleWebSocketClose = () => {
    console.log("WebSocket connection closed");
  };

  // Send a message to the server via WebSocket
  sendMessage(event) {
    event.preventDefault();

    const message = this.inputTarget.value.trim();
    if (!message) {
      alert("Message cannot be empty!");
      return;
    }

    if (this.websocket && this.websocket.readyState === WebSocket.OPEN) {
      this.startTimer();
      this.websocket.send(message);
      this.inputTarget.value = "";
      this.displayMessage({ message, sender: "user" });
    } else {
      console.error("WebSocket connection is not available");
    }
  }

  // Start the timer to calculate elapsed time
  startTimer() {
    this.startTime = performance.now();
  }

  // Calculate the elapsed time since the message was sent
  calculateElapsedTime() {
    const endTime = performance.now();
    return `${Math.round(endTime - this.startTime)}ms`;
  }

  // Process incoming messages from the server
  processIncomingMessage(data, messageElement) {
    if (data.type === "response.text.done") {
      const elapsedTime = this.calculateElapsedTime();
      this.updateMessageInfo(messageElement, elapsedTime);
    } else if (data.type === "response.text.delta") {
      this.appendToMessageText(messageElement, data.delta);
    }
  }

  // Display a message in the chat
  displayMessage({ message, id = null, sender }) {
    const alignment = sender === "user" ? "end" : "start";
    const messageInfo = sender === "user" ? "" : "Typing...";
    const messageId = id ? `id="${id}"` : "";

    const messageElement = `
      <div class="d-flex justify-content-${alignment}">
        <div ${messageId} class="bg-dark text-light px-3 py-2 my-2 rounded-4" style="max-width: 75%">
          <div class="message-text">${message}</div>
          <div class="message-info text-end small opacity-75">${messageInfo}</div>
        </div>
      </div>
    `;

    this.chatTarget.innerHTML += messageElement;
    this.chatTarget.lastElementChild.scrollIntoView({ behavior: "smooth" });
  }

  // Append text to the existing message
  appendToMessageText(messageElement, text) {
    const messageTextElement = messageElement.querySelector(".message-text");
    messageTextElement.textContent += text;
  }

  // Update the message information
  updateMessageInfo(messageElement, info) {
    const messageInfoElement = messageElement.querySelector(".message-info");
    messageInfoElement.textContent = info;
  }
}
