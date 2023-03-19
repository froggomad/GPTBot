//
//  ContentView.swift
//  GPT4Bot
//
//  Created by Kenneth Dubroff on 3/18/23.
//

import SwiftUI

struct ContentView: View {
    @State var prompt: String = ""
    let manager = OpenAPIManager(openAIKey: "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")
    var body: some View {
        VStack {
            TextField("Prompt", text: $prompt)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding()
                .onSubmit {
                    let message = Message(
                        role: .user,
                        content: prompt.appending(OpenAPIChatRequest.stopString)
                    )
                    manager
                        .getCompletion(
                            model: .gpt3_5Turbo,
                            prompt: message
                        ) { result in
                            switch result {
                            case .success(let response):
                                print(response[0].message.content)
                            case .failure(let error):
                                if (error as NSError).code == -1001 {
                                    print("timed out!")
                                } else if let error = error as? OpenAPIManager.JSONError {
                                    print(error.error.code, ":", error.error.message)
                                }
                                print(error.localizedDescription)
                            }
                        }
                }
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
