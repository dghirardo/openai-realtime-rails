# OpenAI Realtime chat with Ruby on Rails

This project is a prototype demonstrating the integration of **OpenAI Realtime API** with **Ruby on Rails** to create a real-time chat experience. The Rails server acts as a bridge between the client interface and OpenAI's server, managing real-time communication through WebSocket using **fiber-based concurrency** with the `async` gem. The frontend is built with **Bootstrap** for styling and **Stimulus.js** for interactive functionality.

## Getting Started

1. **Clone the repository** and navigate into it.
2. **Install dependencies** with `bundle install`.
3. **Set your OpenAI API key** in the environment as `OPENAI_API_KEY`.
4. **Start the Rails server** with `rails s`.
