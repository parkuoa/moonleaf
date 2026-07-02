import Foundation

let jsonString = """
{"data":[{"id":"xed7wo","url":"https://wallhaven.cc/w/xed7wo","short_url":"https://whvn.cc/xed7wo","views":14,"favorites":2,"source":"","purity":"sfw","category":"people","dimension_x":3200,"dimension_y":2217,"resolution":"3200x2217","ratio":"1.44","file_size":2722317,"file_type":"image/jpeg","created_at":"2026-07-01 10:37:36","colors":["#424153","#000000","#cccccc","#663399","#999999"],"path":"https://w.wallhaven.cc/full/xe/wallhaven-xed7wo.jpg","thumbs":{"large":"https://th.wallhaven.cc/lg/xe/xed7wo.jpg","original":"https://th.wallhaven.cc/orig/xe/xed7wo.jpg","small":"https://th.wallhaven.cc/small/xe/xed7wo.jpg"}}],"meta":{"current_page":1,"last_page":25814,"per_page":24,"total":619513,"query":null,"seed":null}}
"""

struct WHResponse: Codable {
    let data: [WHWallpaper]
    let meta: WHMeta
}
struct WHWallpaper: Codable {
    let id: String
    let url: String
    let short_url: String
    let views: Int
    let favorites: Int
    let source: String
    let purity: String
    let category: String
    let dimension_x: Int
    let dimension_y: Int
    let resolution: String
    let ratio: String
    let file_size: Int
    let file_type: String
    let created_at: String
    let colors: [String]
    let path: String
    let thumbs: WHThumbs
}
struct WHThumbs: Codable {
    let large: String
    let original: String
    let small: String
}
struct WHMeta: Codable {
    let current_page: Int
    let last_page: Int
    let per_page: Int
    let total: Int
    let query: String?
    let seed: String?
}

do {
    let data = jsonString.data(using: .utf8)!
    let decoder = JSONDecoder()
    let response = try decoder.decode(WHResponse.self, from: data)
    print("Success: \(response.data.count) wallpapers")
} catch {
    print("Error: \(error)")
}
