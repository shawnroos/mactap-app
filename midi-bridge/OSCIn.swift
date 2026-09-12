import Foundation
import Darwin

/// Minimal OSC-over-UDP receiver for control messages from a Max device.
/// Delivers (address, args) on its own thread; the handler must hop to
/// wherever the setting is read.
final class OSCIn {

    private let fd: Int32
    private let thread: Thread
    let port: UInt16

    init?(port: UInt16, handler: @escaping (String, [Any]) -> Void) {
        self.port = port
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return nil }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bound = withUnsafePointer(to: &addr) { a in
            a.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(sock, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bound == 0 else {
            Darwin.close(sock)
            return nil
        }
        fd = sock

        thread = Thread {
            let fd = sock
            var buf = [UInt8](repeating: 0, count: 2048)
            while true {
                let n = recv(fd, &buf, buf.count, 0)
                guard n > 0 else { continue }
                if let (address, args) = Self.parse(Array(buf[0..<n])) {
                    handler(address, args)
                }
            }
        }
        thread.name = "MacTap.OSC.in"
        thread.start()
    }

    deinit { Darwin.close(fd) }

    /// Address, then type tags, then big-endian i/f args. Other types end parsing.
    private static func parse(_ p: [UInt8]) -> (String, [Any])? {
        func string(at start: Int) -> (String, Int)? {
            guard let end = p[start...].firstIndex(of: 0) else { return nil }
            guard let s = String(bytes: p[start..<end], encoding: .utf8) else { return nil }
            var next = end + 1
            while next % 4 != 0 { next += 1 }
            return (s, next)
        }
        guard let (address, tagStart) = string(at: 0), address.hasPrefix("/") else { return nil }
        guard tagStart < p.count, let (tags, argStart) = string(at: tagStart), tags.hasPrefix(",") else {
            return (address, [])
        }
        var args: [Any] = []
        var i = argStart
        for t in tags.dropFirst() {
            guard i + 4 <= p.count else { break }
            let be = UInt32(p[i]) << 24 | UInt32(p[i + 1]) << 16 | UInt32(p[i + 2]) << 8 | UInt32(p[i + 3])
            switch t {
            case "i": args.append(Int32(bitPattern: be))
            case "f": args.append(Float(bitPattern: be))
            default: return (address, args)
            }
            i += 4
        }
        return (address, args)
    }
}
