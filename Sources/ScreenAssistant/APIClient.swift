import Foundation

struct APIClient {
    let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func analyzeImage(base64Image: String, completion: @escaping (String?) -> Void) {
        // Gemini 2.5 Flash endpoint (Current stable as of 2026)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Gemini Payload
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "Analyze this screenshot. Find the correct answer and provide reasoning. Be concise."],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Error serializing JSON: \(error)")
            completion("Error: Failed to serialize request.")
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error fetching data: \(error)")
                completion("Error: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                print("No data received")
                completion("Error: No data received.")
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    // Check for error first
                    if let error = json["error"] as? [String: Any],
                       let message = error["message"] as? String {
                        print("API Error: \(message)")
                        completion("Error: \(message)")
                        return
                    }
                    
                    // Parse success response
                    if let candidates = json["candidates"] as? [[String: Any]],
                       let firstCandidate = candidates.first,
                       let content = firstCandidate["content"] as? [String: Any],
                       let parts = content["parts"] as? [[String: Any]],
                       let firstPart = parts.first,
                       let text = firstPart["text"] as? String {
                        completion(text)
                        return
                    }
                }
                
                print("Could not parse response structure")
                completion("Error: Unexpected response format from Gemini.")
            } catch {
                print("Error parsing JSON: \(error)")
                completion("Error: Failed to parse response.")
            }
        }
        task.resume()
    }
}
