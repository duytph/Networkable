//
//  URLResponseLoggingTests.swift
//  NetworkingTests
//
//  Created by Duy Tran on 7/15/20.
//

import XCTest

class URLResponseLoggingTests: XCTestCase {
    func testLogging() throws {
        let url = URL(string: "https://apple.com")!
        let sut = URLResponse(
            url: url,
            mimeType: nil,
            expectedContentLength: 0,
            textEncodingName: nil)
        let logging = sut.logging()

        XCTAssertFalse(logging.isEmpty)
        XCTAssertFalse(logging.contains("-H"))
        XCTAssertFalse(logging.contains("-d"))
        XCTAssertTrue(logging.contains(url.absoluteString))
    }

    func testLoggingWhenBeingHTTPURLResponse() {
        let url = URL(string: "https://apple.com")!
        let statusCode = 200
        let sut = HTTPURLResponse(
            url: url,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: ["foo": "bar"])!
        let logging = sut.logging()

        XCTAssertFalse(logging.isEmpty)
        XCTAssertTrue(logging.contains("Status Code: \(statusCode)"))
        XCTAssertFalse(logging.contains("-H \"foo\": \"bar\""))
        XCTAssertFalse(logging.contains("-d"))
        XCTAssertTrue(logging.contains(url.absoluteString))
    }
}
