import Foundation
import CoreMIDI

/// A virtual MIDI source. Ableton, Max and anything else on CoreMIDI see it as
/// a hardware controller named `name`; no IAC bus or driver setup needed.
final class MIDIOut {

    private var client = MIDIClientRef()
    private var source = MIDIEndpointRef()
    private let buffer: UnsafeMutableRawPointer
    private static let bufferBytes = 1024

    let name: String

    init?(name: String) {
        self.name = name
        buffer = UnsafeMutableRawPointer.allocate(byteCount: Self.bufferBytes, alignment: 4)

        var status = MIDIClientCreate(name as CFString, nil, nil, &client)
        guard status == noErr else {
            FileHandle.standardError.write("MIDIClientCreate failed: \(status)\n".data(using: .utf8)!)
            buffer.deallocate()
            return nil
        }
        status = MIDISourceCreate(client, name as CFString, &source)
        guard status == noErr else {
            FileHandle.standardError.write("MIDISourceCreate failed: \(status)\n".data(using: .utf8)!)
            buffer.deallocate()
            return nil
        }
        // Without a stable UniqueID Live forgets the port's mappings between runs.
        MIDIObjectSetIntegerProperty(source, kMIDIPropertyUniqueID, Int32(bitPattern: 0x4D_54_41_50))
    }

    deinit {
        MIDIEndpointDispose(source)
        MIDIClientDispose(client)
        buffer.deallocate()
    }

    func send(_ bytes: [UInt8]) {
        let list = buffer.bindMemory(to: MIDIPacketList.self, capacity: 1)
        let packet = MIDIPacketListInit(list)
        _ = MIDIPacketListAdd(list, Self.bufferBytes, packet, 0, bytes.count, bytes)
        MIDIReceived(source, list)
    }

    func noteOn(channel: UInt8, note: UInt8, velocity: UInt8) {
        send([0x90 | (channel & 0x0F), note & 0x7F, velocity & 0x7F])
    }

    func noteOff(channel: UInt8, note: UInt8) {
        send([0x80 | (channel & 0x0F), note & 0x7F, 0])
    }
}
