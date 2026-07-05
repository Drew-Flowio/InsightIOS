import Foundation
import InsightCore
import LlamaSwift

enum ChatPromptFormatter {
    static func formatPrompt(messages: [ChatMessage], model: OpaquePointer) throws -> String {
        let roles = messages.map(\.role)
        let contents = messages.map(\.content)

        let requiredSize = max(8192, messages.reduce(0) { partial, message in
            partial + message.content.utf8.count + message.role.utf8.count + 32
        })

        return try roles.withCStringArray(contents: contents) { chatMessages in
            let template = llama_model_chat_template(model, nil)
            var buffer = [CChar](repeating: 0, count: requiredSize)
            let written = llama_chat_apply_template(
                template,
                chatMessages,
                chatMessages.count,
                true,
                &buffer,
                Int32(buffer.count)
            )

            if written < 0 {
                throw LlamaRuntimeError.promptFormattingFailed
            }

            if written >= buffer.count {
                buffer = [CChar](repeating: 0, count: Int(written) + 1)
                let retry = llama_chat_apply_template(
                    template,
                    chatMessages,
                    chatMessages.count,
                    true,
                    &buffer,
                    Int32(buffer.count)
                )
                guard retry >= 0, retry < buffer.count else {
                    throw LlamaRuntimeError.promptFormattingFailed
                }
                return String(cString: buffer)
            }

            return String(cString: buffer)
        }
    }
}

private extension Array where Element == String {
    func withCStringArray<T>(contents: [String], body: ([llama_chat_message]) throws -> T) rethrows -> T {
        var rolePointers: [UnsafeMutablePointer<CChar>?] = []
        var contentPointers: [UnsafeMutablePointer<CChar>?] = []
        var chatMessages: [llama_chat_message] = []

        for index in indices {
            let rolePtr = strdup(self[index])
            let contentPtr = strdup(contents[index])
            rolePointers.append(rolePtr)
            contentPointers.append(contentPtr)
            chatMessages.append(llama_chat_message(role: rolePtr, content: contentPtr))
        }

        defer {
            for pointer in rolePointers + contentPointers {
                if let pointer {
                    free(pointer)
                }
            }
        }

        return try body(chatMessages)
    }
}
