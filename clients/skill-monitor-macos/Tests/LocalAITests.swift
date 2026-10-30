import Foundation

private final class SyntheticAIProtocol: URLProtocol, @unchecked Sendable {
    static var handler: ((SyntheticAIProtocol) -> Void)?
    static let lock = NSLock()
    static var stops = 0
    private var stopped = false
    private let stateLock = NSLock()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() { Self.handler?(self) }
    override func stopLoading() {
        stateLock.lock(); stopped = true; stateLock.unlock()
        Self.lock.lock(); Self.stops += 1; Self.lock.unlock()
    }
    func send(_ body: Data, status: Int = 200, headers: [String: String] = ["Content-Type": "application/json"], finish: Bool = true) {
        stateLock.lock(); defer { stateLock.unlock() }
        guard !stopped else { return }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        if finish { client?.urlProtocolDidFinishLoading(self) }
    }
    func chunk(_ body: Data) {
        stateLock.lock(); defer { stateLock.unlock() }
        if !stopped { client?.urlProtocol(self, didLoad: body) }
    }
    func fail(_ error: Error) { client?.urlProtocol(self, didFailWithError: error) }
}

private final class ChallengeSink: NSObject, URLAuthenticationChallengeSender {
    func use(_ credential: URLCredential, for challenge: URLAuthenticationChallenge) {}
    func continueWithoutCredential(for challenge: URLAuthenticationChallenge) {}
    func cancel(_ challenge: URLAuthenticationChallenge) {}
}

@main
struct LocalAITests {
    static var checks = 0
    static func expect(_ value: @autoclosure () -> Bool, _ message: String) {
        checks += 1
        if !value() { fatalError("FAIL: " + message) }
    }
    static func rejects(_ code: String, _ operation: () async throws -> Void) async {
        do { try await operation(); expect(false, "expected " + code) }
        catch let error as LocalAIError { expect(error.code == code, "expected " + code + ", got " + error.code) }
        catch { expect(false, "unexpected error type") }
    }
    static func json(_ value: Any) -> Data { try! JSONSerialization.data(withJSONObject: value) }
    static func client(deadline: TimeInterval = 1) -> LocalAIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SyntheticAIProtocol.self]
        return LocalAIClient(configuration: configuration, modelsDeadline: deadline, analysisDeadline: deadline)
    }
    static func main() async throws {
        for address in ["http://localhost:9944/v1", "https://127.0.0.1:9944/v1", "http://127.0.0.2:9944/v1", "http://[::1]:9944/v1", "http://127.0.0.1/v1", "http://127.0.0.1:0/v1", "http://127.0.0.1:65536/v1", "http://127.0.0.1:9944/v1?x", "http://127.0.0.1:9944/v1#x", "http://x@127.0.0.1:9944/v1", "http://127.0.0.1:9944/v1/../v1", "http://127.0.0.1:9944/%761", "http://127.0.0.1:9944/v1//", " http://127.0.0.1:9944/v1", "http://127.0.0.1:09944/v1", "http://127.0.0.1:9944/v1\\", "//127.0.0.1:9944/v1"] {
            await rejects("invalid_endpoint") { _ = try LocalAIEndpoint(address: address) }
        }
        for port in [-1, 0, 65536, Int.max] { await rejects("invalid_endpoint") { _ = try LocalAIEndpoint(port: port) } }
        let endpoint = try LocalAIEndpoint(port: 9944)
        let trailing = try LocalAIEndpoint(address: "http://127.0.0.1:9944/v1/")
        expect(trailing == endpoint, "normalizes one trailing slash")
        expect(endpoint.baseURL.absoluteString == "http://127.0.0.1:9944/v1", "fixed canonical base")
        let low = try LocalAIEndpoint(port: 1); let high = try LocalAIEndpoint(port: 65535)
        expect(low.port == 1 && high.port == 65535, "full valid port range")
        let api = client()
        let localPath = "/models/mlx/local"
        SyntheticAIProtocol.handler = { stub in
            expect(stub.request.httpMethod == "GET" && stub.request.url?.path == "/v1/models", "only model list GET")
            expect(stub.request.value(forHTTPHeaderField: "Authorization") == nil, "no credentials")
            stub.send(json(["object": "list", "data": [["id": localPath], ["id": "mlx/Qwen"], ["id": localPath], ["id": "gpt-oss:20b"], ["id": "google/gemma3"], ["id": "qwen:cloud"], ["id": "remote@cloud"]]]))
        }
        let models = try await api.models(endpoint: endpoint)
        expect(models.map(\.id) == [localPath, "mlx/Qwen", "gpt-oss:20b", "google/gemma3"], "local model names retained and deduplicated while explicit cloud entries filtered")
        SyntheticAIProtocol.handler = { $0.send(json(["object": "list", "data": [["id": "qwen:cloud"], ["id": "remote@CLOUD"]]])) }
        let cloudOnly = try await api.models(endpoint: endpoint)
        expect(cloudOnly.isEmpty, "cloud-only catalog yields no selectable models")
        SyntheticAIProtocol.handler = { stub in
            expect(stub.request.httpMethod == "POST" && stub.request.url?.path == "/v1/chat/completions", "only chat POST")
            let stream = stub.request.httpBodyStream!
            stream.open(); defer { stream.close() }
            var bytes = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let count = stream.read(&buffer, maxLength: buffer.count); if count <= 0 { break }; bytes.append(buffer, count: count) }
            let body = try! JSONSerialization.jsonObject(with: bytes) as! [String: Any]
            expect(body["model"] as? String == localPath, "exact local model ID")
            expect(body["stream"] as? Bool == false && body["max_tokens"] as? Int == 512 && body["temperature"] as? Int == 0, "bounded deterministic nonstreaming request")
            expect(Set(body.keys) == ["model", "messages", "stream", "max_tokens", "temperature"], "no tools or provider extensions")
            let messages = body["messages"] as! [[String: String]]
            expect(messages == [["role": "system", "content": "policy"], ["role": "user", "content": "metadata"]], "text-only messages")
            stub.send(json(["choices": [["finish_reason": "stop", "message": ["role": "assistant", "content": "<script>plain text</script>"]]]]))
        }
        let text = try await api.analyze(endpoint: endpoint, modelID: localPath, systemPrompt: "policy", userPrompt: "metadata")
        expect(text == "<script>plain text</script>", "model output stays plaintext")
        for reason in ["length", "content_filter"] {
            SyntheticAIProtocol.handler = { $0.send(json(["choices": [["finish_reason": reason, "message": ["content": "partial output"]]]])) }
            await rejects("incomplete_response") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: "x") }
        }
        for reason: Any in [NSNull(), "unknown", "tool_calls", "function_call"] {
            SyntheticAIProtocol.handler = { $0.send(json(["choices": [["finish_reason": reason, "message": ["content": "plausible output"]]]])) }
            await rejects("invalid_response") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: "x") }
        }
        SyntheticAIProtocol.handler = { $0.send(json(["choices": [["message": ["content": "missing completion status"]]]])) }
        await rejects("invalid_response") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: "x") }
        for id in ["qwen:cloud", "remote@cloud", "https://provider.invalid/model", "bad\nID", "", String(repeating: "x", count: 257)] {
            await rejects("invalid_model") { _ = try await api.analyze(endpoint: endpoint, modelID: id, systemPrompt: "", userPrompt: "x") }
        }
        await rejects("input_too_large") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: String(repeating: "x", count: 8193), userPrompt: "x") }
        await rejects("input_too_large") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: String(repeating: "é", count: 49153)) }
        SyntheticAIProtocol.handler = { $0.send(json(["choices": [["finish_reason": "stop", "message": ["content": String(repeating: "é", count: 16384)]]]])) }
        let boundaryText = try await api.analyze(endpoint: endpoint, modelID: String(repeating: "m", count: 256), systemPrompt: String(repeating: "s", count: 8192), userPrompt: String(repeating: "é", count: 49152))
        expect(boundaryText.utf8.count == 32768, "exact UTF8 input, model, and output limits accepted")
        for id in ["gpt-oss:20b", "google/gemma3"] {
            let localText = try await api.analyze(endpoint: endpoint, modelID: id, systemPrompt: "", userPrompt: "metadata")
            expect(localText.utf8.count == 32768, "local model name allowed for analysis: " + id)
        }
        for value: Any in [["data": []], ["object": "list", "data": [["id": 5]]], ["object": "list", "data": ["not an object"]], ["object": "list", "data": Array(repeating: ["id": "local"], count: 129)], ["object": "list", "data": [["id": "https://provider.invalid/model"]]], ["object": "list", "data": [["id": "bad\nID"]]]] {
            SyntheticAIProtocol.handler = { $0.send(json(value)) }
            await rejects("invalid_response") { _ = try await api.models(endpoint: endpoint) }
        }
        for body in [Data("not json".utf8), Data("[]".utf8)] {
            SyntheticAIProtocol.handler = { $0.send(body) }
            await rejects("invalid_response") { _ = try await api.models(endpoint: endpoint) }
        }
        for status in [201, 301, 401, 429, 500] {
            SyntheticAIProtocol.handler = { $0.send(Data("SENTINEL_SERVER_SECRET".utf8), status: status) }
            await rejects("http_status") { _ = try await api.models(endpoint: endpoint) }
        }
        for headers in [["Content-Type": "text/html"], ["Content-Type": "application/json", "Content-Length": "broken"], ["Content-Type": "application/json", "Content-Length": "-1"], ["Content-Type": "application/json", "Content-Length": "9999999999999999999999999"]] {
            SyntheticAIProtocol.handler = { $0.send(Data(), headers: headers) }
            await rejects("invalid_response") { _ = try await api.models(endpoint: endpoint) }
        }
        SyntheticAIProtocol.handler = { $0.send(Data(), headers: ["Content-Type": "application/json", "Content-Length": "262145"]) }
        await rejects("response_too_large") { _ = try await api.models(endpoint: endpoint) }
        SyntheticAIProtocol.handler = { stub in
            stub.send(Data(repeating: 32, count: 131072), finish: false)
            stub.chunk(Data(repeating: 32, count: 131072))
            stub.chunk(Data([32]))
        }
        await rejects("response_too_large") { _ = try await api.models(endpoint: endpoint) }
        SyntheticAIProtocol.handler = { stub in
            stub.send(Data(repeating: 32, count: 262145), headers: ["Content-Type": "application/json", "Content-Length": "20", "Content-Encoding": "gzip"])
        }
        await rejects("response_too_large") { _ = try await api.models(endpoint: endpoint) }
        let boundaryModels = json(["object": "list", "data": [["id": "local"]]])
        SyntheticAIProtocol.handler = { stub in
            var data = boundaryModels; data.append(Data(repeating: 32, count: 262144 - data.count))
            stub.send(data)
        }
        let boundaryResponse = try await api.models(endpoint: endpoint)
        expect(boundaryResponse == [LocalAIModel(id: "local")], "exact response byte cap accepted")
        for message: [String: Any] in [["content": "safe", "tool_calls": []], ["content": "safe", "function_call": NSNull()], ["content": ["parts"]], ["content": String(repeating: "x", count: 32769)], ["content": "", "role": "assistant"]] {
            SyntheticAIProtocol.handler = { $0.send(json(["choices": [["finish_reason": "stop", "message": message]]])) }
            await rejects("invalid_response") { _ = try await api.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: "x") }
        }
        SyntheticAIProtocol.handler = { $0.send(json(["object": "list", "data": []])) }
        let empty = try await api.models(endpoint: endpoint)
        expect(empty.isEmpty, "valid empty model list")
        SyntheticAIProtocol.handler = { $0.fail(NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost, userInfo: [NSLocalizedDescriptionKey: "SENTINEL_RAW_ERROR_URL"])) }
        await rejects("transport") { _ = try await api.models(endpoint: endpoint) }
        SyntheticAIProtocol.handler = { $0.fail(URLError(.timedOut)) }
        await rejects("timeout") { _ = try await api.models(endpoint: endpoint) }
        SyntheticAIProtocol.handler = { _ in }
        let beforeCancel = SyntheticAIProtocol.stops
        let task = Task { try await api.models(endpoint: endpoint) }
        try await Task.sleep(nanoseconds: 30_000_000)
        task.cancel()
        do { _ = try await task.value; expect(false, "cancellation must throw") }
        catch is CancellationError { expect(true, "structured cancellation") }
        catch { expect(false, "wrong cancellation error") }
        try await Task.sleep(nanoseconds: 30_000_000)
        expect(SyntheticAIProtocol.stops > beforeCancel, "cancellation stops transport")
        let short = client(deadline: 0.12)
        let start = Date()
        await rejects("timeout") { _ = try await short.models(endpoint: endpoint) }
        expect(Date().timeIntervalSince(start) < 0.7, "absolute deadline bounds stalled response")
        SyntheticAIProtocol.handler = { stub in
            stub.send(Data([32]), finish: false)
            for tick in 1...20 { DispatchQueue.global().asyncAfter(deadline: .now() + Double(tick) * 0.02) { stub.chunk(Data([32])) } }
        }
        let trickleStart = Date()
        await rejects("timeout") { _ = try await short.models(endpoint: endpoint) }
        expect(Date().timeIntervalSince(trickleStart) < 0.7, "slow trickle cannot reset absolute deadline")
        SyntheticAIProtocol.handler = { _ in }
        await rejects("timeout") { _ = try await short.analyze(endpoint: endpoint, modelID: "local", systemPrompt: "", userPrompt: "x") }
        let delegate = LocalAIResponseOperation(configuration: .ephemeral, deadline: 1)
        let dummy = URLSession(configuration: .ephemeral)
        let dummyTask = dummy.dataTask(with: endpoint.baseURL)
        var redirectWasRejected = false
        delegate.urlSession(dummy, task: dummyTask, willPerformHTTPRedirection: HTTPURLResponse(url: endpoint.baseURL, statusCode: 302, httpVersion: nil, headerFields: nil)!, newRequest: URLRequest(url: URL(string: "https://example.invalid")!)) { redirectWasRejected = $0 == nil }
        expect(redirectWasRejected, "redirect handler rejects every destination")
        let protection = URLProtectionSpace(host: "127.0.0.1", port: 9944, protocol: "http", realm: nil, authenticationMethod: NSURLAuthenticationMethodHTTPBasic)
        let challenge = URLAuthenticationChallenge(protectionSpace: protection, proposedCredential: URLCredential(user: "fixture", password: "fixture", persistence: .none), previousFailureCount: 0, failureResponse: nil, error: nil, sender: ChallengeSink())
        var challengeWasRejected = false
        delegate.urlSession(dummy, didReceive: challenge) { disposition, credential in challengeWasRejected = disposition == .cancelAuthenticationChallenge && credential == nil }
        expect(challengeWasRejected, "session challenge rejects credentials")
        challengeWasRejected = false
        delegate.urlSession(dummy, task: dummyTask, didReceive: challenge) { disposition, credential in challengeWasRejected = disposition == .cancelAuthenticationChallenge && credential == nil }
        expect(challengeWasRejected, "task challenge rejects credentials")
        let preCancelled = LocalAIResponseOperation(configuration: .ephemeral, deadline: 1)
        preCancelled.cancel()
        do { _ = try await preCancelled.run(URLRequest(url: endpoint.baseURL)); expect(false, "prestart cancellation") }
        catch is CancellationError { expect(true, "cancellation before continuation registration") }
        catch { expect(false, "prestart cancellation error type") }
        dummy.invalidateAndCancel()
        expect(LocalAIError.transport.localizedDescription == "transport" && !LocalAIError.transport.localizedDescription.contains("SENTINEL"), "stable sanitized error description")
        print("PASS: \(checks) local AI connector checks (synthetic URLProtocol only)")
    }
}
