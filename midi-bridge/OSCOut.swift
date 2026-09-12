import Foundation
import Darwin

/// Minimal OSC-over-UDP sender, enough for Max's [udpreceive].
final class OSCOut {

    private let fd: Int32
    private var addr: sockaddr_in

    let host: String
    let port: UInt16

    init?(host: String, port: UInt16) {
        self.host = host
        self.port = port

        fd = socket(AF_INET, SOCK_DGRAM, 0)
        guard fd >= 0 else { return nil }

        addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            Darwin.close(fd)
            return nil
        }
    }

    deinit { Darwin.close(fd) }

    /// Args are Int32 or Float32; anything else is skipped.
    func send(address: String, args: [Any]) {
        var packet = Data()
        packet.append(Self.padded(address))

        var tags = ","
        for arg in args {
            if arg is Int32 || arg is Int { tags += "i" }
            else if arg is Float || arg is Double { tags += "f" }
        }
        packet.append(Self.padded(tags))

        for arg in args {
            if let i = arg as? Int32 {
                packet.append(Self.bigEndian(UInt32(bitPattern: i)))
            } else if let i = arg as? Int {
                packet.append(Self.bigEndian(UInt32(bitPattern: Int32(truncatingIfNeeded: i))))
            } else if let f = arg as? Float {
                packet.append(Self.bigEndian(f.bitPattern))
            } else if let d = arg as? Double {
                packet.append(Self.bigEndian(Float(d).bitPattern))
            }
        }

        packet.withUnsafeBytes { raw in
            withUnsafePointer(to: &addr) { a in
                _ = a.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    sendto(fd, raw.baseAddress, raw.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    /// OSC strings are null-terminated then padded to a 4-byte boundary.
    private static func padded(_ s: String) -> Data {
        var d = Data(s.utf8)
        d.append(0)
        while d.count % 4 != 0 { d.append(0) }
        return d
    }

    private static func bigEndian(_ v: UInt32) -> Data {
        var be = v.bigEndian
        return withUnsafeBytes(of: &be) { Data($0) }
    }
}
