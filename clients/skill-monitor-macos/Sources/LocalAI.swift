import Foundation

struct LocalAIEndpoint: Equatable, Sendable {
    let port: Int
    var baseURL: URL { URL(string: "http://127.0.0.1:\(port)/v1")! }

    init(port: Int) throws {
        guard (1...65535).contains(port) else { throw LocalAIError.invalidEndpoint }
        self.port = port
    }

    init(address: String) throws {
        // Match the original bytes before Foundation can normalize URL syntax.
        let prefix = "http://127.0.0.1:"
        guard address.hasPrefix(prefix) else { throw LocalAIError.invalidEndpoint }
        let suffix = address.dropFirst(prefix.count)
        guard let slash = suffix.firstIndex(of: "/"),
              suffix[slash...] == "/v1" || suffix[slash...] == "/v1/" else {
            throw LocalAIError.invalidEndpoint
        }
        let digits = suffix[..<slash]
        guard !digits.isEmpty, digits.first != "0", digits.utf8.allSatisfy({ (48...57).contains($0) }),
              let port = Int(digits) else { throw LocalAIError.invalidEndpoint }
        try self.init(port: port)
    }
}

struct LocalAIModel: Equatable, Identifiable, Sendable {
    let id: String
}

enum LocalAIError: String, Error, LocalizedError, Sendable {
    case invalidEndpoint = "invalid_endpoint"
    case invalidModel = "invalid_model"
    case inputTooLarge = "input_too_large"
    case invalidResponse = "invalid_response"
    case responseTooLarge = "response_too_large"
    case httpStatus = "http_status"
    case redirectRejected = "redirect_rejected"
    case authenticationRejected = "authentication_rejected"
    case incompleteResponse = "incomplete_response"
    case timeout
    case transport
    var code: String { rawValue }
    var errorDescription: String? { code }
}

final class LocalAIClient: @unchecked Sendable {
    private let configuration: URLSessionConfiguration
    private let modelsDeadline: TimeInterval
    private let analysisDeadline: TimeInterval

    convenience init() { self.init(configuration: .ephemeral) }

    // Injection is internal and used only for synthetic URLProtocol fixtures.
    init(configuration: URLSessionConfiguration, modelsDeadline: TimeInterval = 15, analysisDeadline: TimeInterval = 30) {
        let isolated = URLSessionConfiguration.ephemeral
        isolated.protocolClasses = configuration.protocolClasses
        isolated.httpCookieStorage = nil
        isolated.httpShouldSetCookies = false
        isolated.httpCookieAcceptPolicy = .never
        isolated.urlCache = nil
        isolated.requestCachePolicy = .reloadIgnoringLocalCacheData
        isolated.urlCredentialStorage = nil
        isolated.httpAdditionalHeaders = [:]
        isolated.connectionProxyDictionary = [
            "HTTPEnable": 0, "HTTPSEnable": 0, "SOCKSEnable": 0,
            "ProxyAutoConfigEnable": 0, "ProxyAutoDiscoveryEnable": 0,
            "ExceptionsList": ["127.0.0.1"], "ExcludeSimpleHostnames": 1,
        ]
        isolated.waitsForConnectivity = false
        self.configuration = isolated
        self.modelsDeadline = modelsDeadline.isFinite && modelsDeadline > 0 ? min(modelsDeadline, 15) : 15
        self.analysisDeadline = analysisDeadline.isFinite && analysisDeadline > 0 ? min(analysisDeadline, 30) : 30
    }

    func models(endpoint: LocalAIEndpoint) async throws -> [LocalAIModel] {
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent("models"))
        request.httpMethod = "GET"
        let data = try await perform(request, deadline: modelsDeadline)
        let object = try Self.object(data)
        guard object["object"] as? String == "list", let entries = object["data"] as? [[String: Any]], entries.count <= 128 else {
            throw LocalAIError.invalidResponse
        }
        var seen = Set<String>()
        return try entries.compactMap { entry in
            guard let id = entry["id"] as? String, Self.validModel(id) else { throw LocalAIError.invalidResponse }
            guard !Self.explicitCloudModel(id) else { return nil }
            return seen.insert(id).inserted ? LocalAIModel(id: id) : nil
        }
    }

    func analyze(endpoint: LocalAIEndpoint, modelID: String, systemPrompt: String, userPrompt: String) async throws -> String {
        guard Self.validModel(modelID), !Self.explicitCloudModel(modelID) else { throw LocalAIError.invalidModel }
        guard systemPrompt.utf8.count <= 8 * 1024, userPrompt.utf8.count <= 96 * 1024 else { throw LocalAIError.inputTooLarge }
        var request = URLRequest(url: endpoint.baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": modelID, "stream": false, "max_tokens": 512, "temperature": 0,
            "messages": [["role": "system", "content": systemPrompt], ["role": "user", "content": userPrompt]],
        ])
        let object = try Self.object(try await perform(request, deadline: analysisDeadline))
        guard let choices = object["choices"] as? [[String: Any]], choices.count == 1,
              let finishReason = choices[0]["finish_reason"] as? String else { throw LocalAIError.invalidResponse }
        if finishReason == "length" || finishReason == "content_filter" { throw LocalAIError.incompleteResponse }
        guard finishReason == "stop", let message = choices[0]["message"] as? [String: Any],
              message["tool_calls"] == nil, message["function_call"] == nil,
              choices[0]["tool_calls"] == nil, choices[0]["function_call"] == nil,
              object["tool_calls"] == nil, object["function_call"] == nil,
              let text = message["content"] as? String, !text.isEmpty, text.utf8.count <= 32 * 1024 else {
            throw LocalAIError.invalidResponse
        }
        return text
    }

    private func perform(_ input: URLRequest, deadline: TimeInterval) async throws -> Data {
        try Task.checkCancellation()
        var request = input
        request.timeoutInterval = deadline
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let operation = LocalAIResponseOperation(configuration: configuration, deadline: deadline)
        return try await withTaskCancellationHandler(operation: {
            try await operation.run(request)
        }, onCancel: { operation.cancel() })
    }

    private static func object(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data), let object = value as? [String: Any] else {
            throw LocalAIError.invalidResponse
        }
        return object
    }

    private static func validModel(_ id: String) -> Bool {
        guard !id.isEmpty, id.utf8.count <= 256,
              id == id.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { return false }
        return !id.contains("://")
    }

    private static func explicitCloudModel(_ id: String) -> Bool {
        let key = id.lowercased()
        return key.hasSuffix(":cloud") || key.hasSuffix("@cloud")
    }
}

// URLSession delivers decompressed chunks here. The bound is checked before
// appending; neither data(for:) nor completion-handler buffering is used.
final class LocalAIResponseOperation: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private static let byteLimit = 256 * 1024
    private let lock = NSLock()
    private let configuration: URLSessionConfiguration
    private let deadline: TimeInterval
    private var continuation: CheckedContinuation<Data, Error>?
    private var result: Result<Data, Error>?
    private var session: URLSession?
    private var task: URLSessionDataTask?
    private var timer: DispatchWorkItem?
    private var bytes = Data()
    private var acceptedResponse = false

    init(configuration: URLSessionConfiguration, deadline: TimeInterval) {
        self.configuration = configuration
        self.deadline = deadline
    }

    func run(_ request: URLRequest) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.lock()
            if let result = result {
                lock.unlock()
                continuation.resume(with: result)
                return
            }
            self.continuation = continuation
            let config = configuration.copy() as! URLSessionConfiguration
            config.timeoutIntervalForRequest = deadline
            config.timeoutIntervalForResource = deadline
            let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
            let task = session.dataTask(with: request)
            let timer = DispatchWorkItem { [weak self] in self?.finish(.failure(LocalAIError.timeout)) }
            self.session = session; self.task = task; self.timer = timer
            // An independent monotonic deadline cannot be extended by trickling bytes.
            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + deadline, execute: timer)
            lock.unlock()
            task.resume()
        }
    }

    func cancel() { finish(.failure(CancellationError())) }

    private func finish(_ outcome: Result<Data, Error>) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        result = outcome
        let continuation = self.continuation
        let task = self.task; let session = self.session; let timer = self.timer
        self.continuation = nil; self.task = nil; self.session = nil; self.timer = nil
        bytes = Data()
        lock.unlock()
        timer?.cancel(); task?.cancel(); session?.invalidateAndCancel()
        continuation?.resume(with: outcome)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let response = response as? HTTPURLResponse else {
            completionHandler(.cancel); finish(.failure(LocalAIError.invalidResponse)); return
        }
        guard response.statusCode == 200 else {
            completionHandler(.cancel); finish(.failure(LocalAIError.httpStatus)); return
        }
        guard response.mimeType?.lowercased() == "application/json" else {
            completionHandler(.cancel); finish(.failure(LocalAIError.invalidResponse)); return
        }
        if let raw = response.value(forHTTPHeaderField: "Content-Length") {
            guard !raw.isEmpty, raw.utf8.allSatisfy({ (48...57).contains($0) }), let count = UInt64(raw) else {
                completionHandler(.cancel); finish(.failure(LocalAIError.invalidResponse)); return
            }
            guard count <= UInt64(Self.byteLimit) else {
                completionHandler(.cancel); finish(.failure(LocalAIError.responseTooLarge)); return
            }
        }
        lock.lock(); let active = result == nil; acceptedResponse = active; lock.unlock()
        completionHandler(active ? .allow : .cancel)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        lock.lock()
        guard result == nil else { lock.unlock(); return }
        guard acceptedResponse else { lock.unlock(); finish(.failure(LocalAIError.invalidResponse)); return }
        guard data.count <= Self.byteLimit - bytes.count else {
            lock.unlock(); finish(.failure(LocalAIError.responseTooLarge)); return
        }
        bytes.append(data)
        lock.unlock()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            let code = (error as NSError).code
            finish(.failure(code == NSURLErrorTimedOut ? LocalAIError.timeout : LocalAIError.transport))
        } else {
            lock.lock(); let accepted = acceptedResponse; let data = bytes; lock.unlock()
            finish(accepted ? .success(data) : .failure(LocalAIError.invalidResponse))
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(nil)
        finish(.failure(LocalAIError.redirectRejected))
    }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.cancelAuthenticationChallenge, nil)
        finish(.failure(LocalAIError.authenticationRejected))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.cancelAuthenticationChallenge, nil)
        finish(.failure(LocalAIError.authenticationRejected))
    }
}
