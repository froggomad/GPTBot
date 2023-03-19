//
//  ChatModel.swift
//  GPT4Bot
//
//  Created by Kenneth Dubroff on 3/18/23.
//

import Foundation

enum MessageRole: String, Codable {
    case assistant
    case system
    case user
}

struct Message: Codable {
    let role: MessageRole
    let content: String
}
