//
//  OpenAPIManager.swift
//  GPT4Bot
//
//  Created by Kenneth Dubroff on 3/18/23.
//
import Foundation

/// connect's to openAI and facilitates conversations with GPT-4
class OpenAPIManager {

    struct JSONError: Decodable, Error {
        let error: Error

        struct Error: Decodable {
            let message: String
            let type: String?
            let code: String?
        }
    }

    let openAIKey: String
    let session: URLSession
    let baseURL: URL
    var prompts: [Message] = []

    init(openAIKey: String, session: URLSession = .shared, baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.openAIKey = openAIKey
        self.session = session
        self.baseURL = baseURL
    }
    /// Create a request to the chat completion endpoint
    /// - add the prompt to self.prompts
    /// - make the request
    /// - on error, remove the prompt from self.prompts
    /// - send all prompts with each request
    func getCompletion(model: OpenAPIChatRequest.ChatModel = .gpt4, prompt: Message, maxTokens: Double = 256, stop: [String] = [OpenAPIChatRequest.stopString], temperature: Double = 0.6, completion: @escaping (Result<[ChatCompletionChoice], Error>) -> Void) {
        addPrompt(prompt)

        let request = OpenAPIChatRequest(model: model, messages: prompts, maxTokens: maxTokens, stop: stop, temperature: temperature)
        let urlRequest = request.urlRequest(baseURL: baseURL, openAIKey: openAIKey)
        session.dataTask(with: urlRequest) { [weak self] data, _, error in
            if let error = error {
                self?.removePrompt(prompt)
                completion(.failure(error))
            } else if let data = data {
                // check for JSON error
                if let error = self?.parseError(from: data) {
                    self?.removePrompt(prompt)
                    completion(.failure(error))
                    return
                }

                do {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase
                    let response = try decoder.decode(OpenAPIChatCompletionResponse.self, from: data)
                    completion(.success(response.choices))
                } catch {
                    self?.removePrompt(prompt)
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func parseError(from data: Data) -> Error? {
        if let error = try? JSONDecoder().decode(JSONError.self, from: data) {
            return error
        } else {
            return nil
        }
    }

    private func addPrompt(_ prompt: Message) {
        self.prompts.append(prompt)
    }

    private func removePrompt(_ prompt: Message) {
        self.prompts.removeAll { $0.content == prompt.content }
    }
}
// MARK: Request
struct OpenAPIChatRequest: Encodable {
    enum ChatModel: String, Encodable {
        /// More capable than any GPT-3.5 model, able to do more complex tasks, and optimized for chat. Will be updated with our latest model iteration.
        case gpt4 = "gpt-4"
        /// Most capable GPT-3.5 model and optimized for chat at 1/10th the cost of text-davinci-003. Will be updated with our latest model iteration
        case gpt3_5Turbo = "gpt-3.5-turbo"
    }

    static let stopString = "@#+_!"
    let model: ChatModel
    let messages: [Message]
    let maxTokens: Double
    /// number of completions to generate for each prompt
    let n: Int
    let stop: [String]
    let temperature: Double

    internal init(model: ChatModel = .gpt4, messages: [Message], maxTokens: Double = 100, stop: [String] = [Self.stopString], temperature: Double = 0.6, n: Int = 1) {
        self.model = model
        self.messages = messages
        self.maxTokens = maxTokens
        self.stop = stop
        self.temperature = temperature
        self.n = n
    }
    /// - creates this request
    ///
    ///        -H "Content-Type: application/json" \
    ///          -H "Authorization: Bearer $OPENAI_API_KEY" \
    ///          -d '{
    ///            "model": "text-davinci-003",
    ///            "messages": [{ "content": "Say this is a test", "role": "user" }],
    ///            "max_tokens": 100,
    ///            "stop": ["\n"],
    ///            "temperature": 0.6,
    ///            "n": 1
    ///          }
    func urlRequest(baseURL: URL, openAIKey: String) -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent("/chat/completions"))
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let data = try encoder.encode(self)
            request.httpBody = data
        } catch {
            print(error)
        }

        return request
    }

}
// MARK: Response
//"usage": {
//        "prompt_tokens": 9,
//        "completion_tokens": 16,
//        "total_tokens": 25
//    },
//    "choices": [{
//        "message": {
//            "role": "assistant",
//            "content": "\n\nI'm sorry, I don't understand what you mean by \"asdf\""
//        },
//        "finish_reason": "stop",
//        "index": 0
//    }]
struct OpenAPIChatCompletionResponse: Codable {
    let usage: Usage
    let choices: [ChatCompletionChoice]
}
//"prompt_tokens": 9,
//"completion_tokens": 16,
//"total_tokens": 25
struct Usage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}
//"message": {
//            "role": "assistant",
//            "content": "\n\nI'm sorry, I don't understand what you mean by \"asdf\""
//        },
//        "finish_reason": "stop",
//        "index": 0
struct ChatCompletionChoice: Codable {
    let message: Message
    let finishReason: String
    let index: Int
}
