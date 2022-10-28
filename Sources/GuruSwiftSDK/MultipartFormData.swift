/* Copyright (C) Guru Movement Labs Inc - All Rights Reserved
 * Unauthorized copying of this file, via any medium, is strictly prohibited.
 * Proprietary and confidential.
 */


import Foundation

// Adapted from https://stackoverflow.com/a/69796182/895769
struct MultipartFormDataRequest {
    private let boundary: String = UUID().uuidString
    var httpBody = NSMutableData()
    let url: URL

    init(url: URL) {
        self.url = url
    }

    func addTextField(named name: String, value: String) {
        httpBody.appendString(textFormField(named: name, value: value))
    }

    private func textFormField(named name: String, value: String) -> String {
        var fieldString = "--\(boundary)\r\n"
        fieldString += "Content-Disposition: form-data; name=\"\(name)\"\r\n"
        fieldString += "\r\n"
        fieldString += "\(value)\r\n"

        return fieldString
    }

    func addFile(fileName: String, data: Data, mimeType: String = "video/quicktime") {
        httpBody.append(dataFormField(fieldName: "file", fileName: fileName, data: data, mimeType: mimeType))
    }

    private func dataFormField(fieldName: String,
                               fileName: String,
                               data: Data,
                               mimeType: String) -> Data {
        let fieldData = NSMutableData()

        fieldData.appendString("--\(boundary)\r\n")
        fieldData.appendString("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n")
        fieldData.appendString("Content-Type: \(mimeType)\r\n")
        fieldData.appendString("\r\n")
        fieldData.append(data)
        fieldData.appendString("\r\n")
        return fieldData as Data
    }

    func asURLRequest() -> URLRequest {
        var request = URLRequest(url: url)

        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        httpBody.appendString("--\(boundary)--")
        request.httpBody = httpBody as Data
        return request
    }
}

extension NSMutableData {
    func appendString(_ string: String) {
        if let data = string.data(using: .utf8) {
            self.append(data)
        }
    }
}


extension URLSession {
    func dataTask(with request: MultipartFormDataRequest,
                  completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void)
    -> URLSessionDataTask {
        return dataTask(with: request.asURLRequest(), completionHandler: completionHandler)
    }
}
