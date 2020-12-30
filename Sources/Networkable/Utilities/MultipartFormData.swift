import Foundation

/// Constructs `multipart/form-data` body of a request.
/// The "multipart/form-data" contains a series of parts. Each part is expected to contain a content-disposition header [RFC 2183]
/// where the disposition type is "form-data", and where the disposition contains an (additional) parameter of "name",
/// where the value of thatparameter is the original field name in the form.
public protocol MultipartFormDataBuildable {}

/// Constructs `multipart/form-data` body of a request.
/// The "multipart/form-data" contains a series of parts. Each part is expected to contain a content-disposition header [RFC 2183]
/// where the disposition type is "form-data", and where the disposition contains an (additional) parameter of "name",
/// where the value of thatparameter is the original field name in the form.
public struct MultipartFormDataBuilder: MultipartFormDataBuildable {
    
    /// The possible errors maybe  throw during constructing the multipart form data.
    public enum FormError: Error {
        
        case invalidFileURL(URL)
        case unreachableFileURL(URL)
        case lostFileSize(URL)
        case failedInputStreeamInitialization(URL)
    }
    
    /// The part of a HTTP multipart/form-data request's body.
    public struct Part {
        
        public var inputStream: InputStream
        public var contentLength: UInt64
        public var headers: [String: String]
        
        public init(
            inputStream: InputStream,
            contentLength: UInt64,
            headers: [String: String]) {
            self.inputStream = inputStream
            self.contentLength = contentLength
            self.headers = headers
        }
    }

    // MARK: - Dependencies
    
    /// A string  used to separate body parts.
    public let boundary: String
    
    /// The end of line character
    public let endOfLine: String
    
    /// A  convenient interface to the contents of the file system.
    public let fileManager: FileManager
    
    /// The maximum number of bytes to read from a input stream in turn.
    public let streamBufferSize: Int
    
    /// The part of a HTTP multipart/form-data request's body.
    public private(set) var parts: [Part] = []
    
    // MARK: - Private Properties
    
    private var startingBoundaryData: Data?
    private var endingBoundaryData: Data?
    private var endOfLineData: Data?
    
    // MARK: - Init
    
    /// Create an object has capability of building a HTTP multipart/form-data request's body.
    /// - Parameters:
    ///   - boundary: The boundary used to separate the body parts in the encoded form data.
    ///   - endOfLine: The end of line character
    ///   - fileManager: The interface to the contents of the file system.
    ///   - streamBufferSize: The maximum number of bytes to read from a input stream in turn.
    public init(
        boundary: String = UUID().uuidString.replacingOccurrences(of: "-", with: ""),
        endOfLine: String = "\r\n",
        fileManager: FileManager = .default,
        streamBufferSize: Int = 1024) {
        self.boundary = boundary
        self.endOfLine = endOfLine
        self.fileManager = fileManager
        self.streamBufferSize = streamBufferSize
        
        self.startingBoundaryData = "--\(boundary)\(endOfLine)".data(using: .utf8)
        self.endingBoundaryData = "--\(boundary)--\(endOfLine)".data(using: .utf8)
        self.endOfLineData = endOfLine.data(using: .utf8)
    }
    
    // MARK: - Building
    
    /// Creates a body part from the data and appends it to the instance.
    /// - Parameters:
    ///   - data:     `Data` to encoding into the instance.
    ///   - name:     Name to associate with the `Data` in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the `Data` in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the data in the `Content-Type` HTTP header.
    mutating public func append(
        _ data: Data,
        withName name: String,
        fileName: String? = nil,
        mimeType: String? = nil) throws {
        let inputStream = InputStream(data: data)
        let contentLength = UInt64(data.count)
        let headers = self.headers(
            name: name,
            fileName: fileName,
            mimeType: mimeType)
        let part = Part(
            inputStream: inputStream,
            contentLength: contentLength,
            headers: headers)
        parts.append(part)
    }
    
    /// Creates a body part from the file and appends it to the instance.
    /// - Parameters:
    ///   - fileURL: `URL` of the file whose content will be buildd into the instance.
    ///   - name:    Name to associate with the file content in the `Content-Disposition` HTTP header.
    mutating public func append(
        fileURL: URL,
        name: String) throws {
        let fileName = fileURL.lastPathComponent
        guard
            !fileName.isEmpty,
            let mimeType = fileURL.mimeType()
        else {
            throw FormError.invalidFileURL(fileURL)
        }
        
        try self.append(
            fileURL: fileURL,
            name: name,
            fileName: fileName,
            mimeType: mimeType)
    }
    
    /// Creates a body part from the file and appends it to the instance.
    /// - Parameters:
    ///   - fileURL:  `URL` of the file whose content will be buildd into the instance.
    ///   - name:     Name to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the file content in the `Content-Type` HTTP header.
    mutating public func append(
        fileURL: URL,
        name: String,
        fileName: String,
        mimeType: String) throws {
        var isDirectory: ObjCBool = false
        guard
            fileURL.isFileURL,
            fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory),
            !isDirectory.boolValue
        else {
            throw FormError.invalidFileURL(fileURL)
        }
        
        guard
            try fileURL.checkPromisedItemIsReachable()
        else {
            throw FormError.unreachableFileURL(fileURL)
        }
        
        guard
            let fileSize = try fileManager.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber
        else {
            throw FormError.lostFileSize(fileURL)
        }
        
        guard
            let inputStream = InputStream(url: fileURL)
        else {
            throw FormError.failedInputStreeamInitialization(fileURL)
        }
        
        let headers = self.headers(
            name: name,
            fileName: fileName,
            mimeType: mimeType)

        let contentLength = fileSize.uint64Value
        let part = Part(
            inputStream: inputStream,
            contentLength: contentLength,
            headers: headers)
        parts.append(part)
    }
    
    func build() throws -> Data {
        var data = Data()
        
        guard parts.isEmpty else { return data }
        
        for part in parts {
            startingBoundaryData.map { data.append($0) }
            
            build(headers: part.headers).map { data.append($0) }
            
            endOfLineData.map { data.append($0) }
            
            let inputStream = try build(inputStream: part.inputStream)
            data.append(inputStream)
            
            endOfLineData.map { data.append($0) }
        }
        
        endingBoundaryData.map { data.append($0) }
        
        return data
    }
    
    // MARK: - Utilities
    
    /// Create the headers for a body part, folllowing below formats.
    /// - `Content-Disposition: form-data; name=#{name}; filename=#{filename}` (HTTP Header)
    /// - `Content-Type: #{mimeType}` (HTTP Header)
    /// - Parameters:
    ///   - name: Name to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - fileName: Filename to associate with the file content in the `Content-Disposition` HTTP header.
    ///   - mimeType: MIME type to associate with the file content in the `Content-Type` HTTP header.`
    /// - Returns: A dictionary re-presents the HTTP headers.
    func headers(
        name: String,
        fileName: String? = nil,
        mimeType: String? = nil) -> [String: String] {
        var headers = [String: String]()
        
        mimeType.map { headers["Content-Type"] = $0 }
        
        var disposition = "form-data; name=\(name)"
        fileName.map { disposition += "; filename=\($0)" }
        headers["Content-Type"] = disposition
        
        return headers
    }
    
    func build(headers: [String: String]) -> Data? {
        let headers = headers
            .map { "\($0.key): \($0.value)" }
            .joined(separator: endOfLine)
            + endOfLine
        let data = headers.data(using: .utf8)
        return data
    }
    
    func build(inputStream: InputStream) throws -> Data {
        var data = Data()
        
        inputStream.open()

        while inputStream.hasBytesAvailable {
            var buffer = [UInt8](
                repeating: 0,
                count: streamBufferSize)
            let bytes = inputStream.read(
                &buffer,
                maxLength: streamBufferSize)

            try inputStream
                .streamError
                .map { throw $0 }
            
            guard bytes > 0 else { break }

            data.append(buffer, count: bytes)
        }
        
        endOfLineData.map { data.append($0) }
        
        inputStream.close()
        
        return data
    }
}
