import Foundation
import PlaygroundSupport
PlaygroundPage.current.needsIndefiniteExecution = true

// 1) Point at the real endpoint (limit to 5 so it’s trivial)
let sampleURL = URL(string: "https://data.seattle.gov/resource/gm8h-9449.json?$limit=5")!

URLSession.shared.dataTask(with: sampleURL) { data, resp, err in
  guard let data = data, err == nil else {
    print("Network error:", err ?? "unknown")
    PlaygroundPage.current.finishExecution()
    return
  }

  // 2) Dump raw JSON
  if let jsonString = String(data: data, encoding: .utf8) {
    print("RAW JSON:\n", jsonString)
  }

  // 3) Inspect first record’s keys & types
  if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String:Any]],
     let first = arr.first {
    print("\nKeys and Swift types in first record:")
    for (k,v) in first {
      print(" • \(k):", type(of: v))
    }
  }

  PlaygroundPage.current.finishExecution()
}.resume()
