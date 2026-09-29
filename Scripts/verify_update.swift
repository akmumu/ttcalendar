import CryptoKit
import Foundation

// Verify exactly as a client does, using only its public key. No Keychain access.
guard CommandLine.arguments.count == 4 else {
    fatalError("Usage: swift Scripts/verify_update.swift update.dmg signatureBase64 publicKeyBase64")
}
let arguments = CommandLine.arguments
guard let signature = Data(base64Encoded: arguments[2]),
      let keyData = Data(base64Encoded: arguments[3]) else {
    fatalError("Invalid base64 signature or public key")
}
let key = try Curve25519.Signing.PublicKey(rawRepresentation: keyData)
let archive = try Data(contentsOf: URL(fileURLWithPath: arguments[1]), options: .mappedIfSafe)
guard key.isValidSignature(signature, for: archive) else {
    fatalError("Invalid Sparkle signature: do not publish this archive/feed combination")
}
print("PASS: DMG Ed25519 signature verified against the client public key")
