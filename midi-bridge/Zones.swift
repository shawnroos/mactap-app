import Foundation

/// Where on the chassis a knock landed, learned per machine.
///
/// Features are the attack-window gyro and vertical accel divided by the
/// knock's peak, so a hard and a soft knock in the same spot look alike.
/// Tilt-per-g behaves like distance from the sensor; the direction alone
/// does not separate spots (19/40 on labelled knocks) but these three did
/// (39/40 for front-left / front-right / back).
struct ZoneFeatures: Codable {
    var gyPerG: Double
    var gxPerG: Double
    var zPerG: Double

    init(hit: MusicalHit) {
        let p = max(hit.peakMagnitude, 1e-4)
        gyPerG = hit.attackGY / p
        gxPerG = hit.attackGX / p
        zPerG = hit.attackZ / p
    }

    init(_ v: [Double]) {
        gyPerG = v[0]; gxPerG = v[1]; zPerG = v[2]
    }

    var vector: [Double] { [gyPerG, gxPerG, zPerG] }
}

struct Zone: Codable {
    var name: String
    var note: UInt8
    var samples: [[Double]] = []
    var centroid: [Double] = [0, 0, 0]
    /// Peak g of each learning knock, kept so unequal strength across zones is visible.
    var peaks: [Double] = []

    init(name: String, note: UInt8) {
        self.name = name
        self.note = note
    }

    // Files written before `peaks` existed must still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        note = try c.decode(UInt8.self, forKey: .note)
        samples = try c.decodeIfPresent([[Double]].self, forKey: .samples) ?? []
        centroid = try c.decodeIfPresent([Double].self, forKey: .centroid) ?? [0, 0, 0]
        peaks = try c.decodeIfPresent([Double].self, forKey: .peaks) ?? []
    }
}

struct ZoneMatch {
    let zone: Zone
    let index: Int
    /// How much nearer the best zone is than the runner-up, 0..1. Under ~0.2
    /// the knock sits between two fingerprints.
    let margin: Double
}

final class ZoneModel: Codable {
    var zones: [Zone]
    /// Per-feature pooled within-zone spread, so no feature dominates.
    var scale: [Double] = [1, 1, 1]

    init(zones: [Zone]) {
        self.zones = zones
    }

    static let defaultPath = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".mactap-zones.json")

    static func load(from url: URL) -> ZoneModel? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ZoneModel.self, from: data)
    }

    func save(to url: URL) throws {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url)
    }

    var isFitted: Bool { zones.allSatisfy { $0.samples.count >= 2 } }

    func fit() {
        var sumSq = [0.0, 0.0, 0.0]
        var n = 0
        for i in zones.indices {
            zones[i].centroid = Self.mean(zones[i].samples)
            for s in zones[i].samples {
                for k in 0..<3 { sumSq[k] += (s[k] - zones[i].centroid[k]) * (s[k] - zones[i].centroid[k]) }
            }
            n += max(zones[i].samples.count - 1, 0)
        }
        scale = sumSq.map { max(sqrt($0 / Double(max(n, 1))), 1e-3) }
    }

    func classify(_ f: ZoneFeatures) -> ZoneMatch? {
        classify(f.vector, centroids: zones.map(\.centroid))
    }

    private func classify(_ v: [Double], centroids: [[Double]]) -> ZoneMatch? {
        guard centroids.count >= 2 else { return nil }
        var dists: [(Double, Int)] = []
        for (i, c) in centroids.enumerated() {
            var d = 0.0
            for k in 0..<3 { let t = (v[k] - c[k]) / scale[k]; d += t * t }
            dists.append((sqrt(d), i))
        }
        dists.sort { $0.0 < $1.0 }
        let best = dists[0], next = dists[1]
        let margin = next.0 > 1e-9 ? (next.0 - best.0) / next.0 : 0
        return ZoneMatch(zone: zones[best.1], index: best.1, margin: margin)
    }

    /// Leave-one-out: each sample scored against centroids that exclude it.
    /// Returns confusion[truth][predicted].
    func confusion() -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: zones.count), count: zones.count)
        for (zi, zone) in zones.enumerated() {
            for (si, s) in zone.samples.enumerated() {
                var centroids = zones.map(\.centroid)
                var rest = zone.samples
                rest.remove(at: si)
                if rest.isEmpty { continue }
                centroids[zi] = Self.mean(rest)
                if let m = classify(s, centroids: centroids) {
                    table[zi][m.index] += 1
                }
            }
        }
        return table
    }

    func confusionReport() -> String {
        let table = confusion()
        let width = max(zones.map { $0.name.count }.max() ?? 4, 4) + 2
        var lines = ["zone fingerprints (leave-one-out): rows = where you knocked, columns = what it read"]
        lines.append(String(repeating: " ", count: width + 2) + zones.map { $0.name.padding(toLength: width, withPad: " ", startingAt: 0) }.joined())
        var right = 0, total = 0
        for (i, z) in zones.enumerated() {
            let row = table[i].map { String($0).padding(toLength: width, withPad: " ", startingAt: 0) }.joined()
            lines.append("  " + z.name.padding(toLength: width, withPad: " ", startingAt: 0) + row)
            right += table[i][i]
            total += table[i].reduce(0, +)
        }
        lines.append("  \(right)/\(total) correct")

        // Tilt per g is not linear in g, so a zone knocked harder than the
        // others is learned partly as "hard", and mis-reads later.
        let medians = zones.map { z -> Double in
            let p = z.peaks.sorted()
            return p.isEmpty ? 0 : p[p.count / 2]
        }
        if let lo = medians.min(), let hi = medians.max(), lo > 0 {
            lines.append("  knock strength, median g per zone: " + zip(zones, medians).map { String(format: "%@ %.3f", $0.name, $1) }.joined(separator: ", "))
            if hi / lo > 1.3 {
                lines.append("  WARNING: zones were knocked at different strengths (\(String(format: "%.0f", (hi / lo - 1) * 100))% apart); the model will partly read strength as place. Re-learn knocking every zone the same.")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func mean(_ rows: [[Double]]) -> [Double] {
        guard !rows.isEmpty else { return [0, 0, 0] }
        var m = [0.0, 0.0, 0.0]
        for r in rows { for k in 0..<3 { m[k] += r[k] } }
        return m.map { $0 / Double(rows.count) }
    }
}

/// "front-left:36,front-right:38,back:42" → zones. A missing note takes 36, 38, 40…
func parseZoneSpec(_ spec: String) -> [Zone] {
    spec.split(separator: ",").enumerated().map { i, part in
        let bits = part.split(separator: ":", maxSplits: 1)
        let name = bits[0].trimmingCharacters(in: .whitespaces)
        let note = bits.count > 1 ? UInt8(bits[1].trimmingCharacters(in: .whitespaces)) ?? UInt8(36 + 2 * i) : UInt8(36 + 2 * i)
        return Zone(name: name, note: note)
    }
}
