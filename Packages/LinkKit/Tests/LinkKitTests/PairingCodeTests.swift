import Testing
import Foundation
@testable import LinkKit

@Suite("PairingCode Tests")
struct PairingCodeTests {
    
    @Test("PairingCode generates 6-digit code")
    func testGeneratedCode() {
        let code = PairingCode()
        
        #expect(code.digits.count == 6)
        #expect(code.digits.allSatisfy { $0.isNumber })
    }
    
    @Test("PairingCode is valid initially")
    func testInitialValidity() {
        let code = PairingCode()
        
        #expect(code.isValid == true)
        #expect(code.failedAttempts == 0)
    }
    
    @Test("PairingCode validation succeeds with correct code")
    func testValidationSuccess() {
        var code = PairingCode(digits: "123456")
        
        let result = code.validate("123456")
        
        #expect(result == true)
        #expect(code.failedAttempts == 0)
    }
    
    @Test("PairingCode validation fails with wrong code")
    func testValidationFailure() {
        var code = PairingCode(digits: "123456")
        
        let result = code.validate("654321")
        
        #expect(result == false)
        #expect(code.failedAttempts == 1)
    }
    
    @Test("PairingCode invalidated after max attempts")
    func testMaxAttempts() {
        var code = PairingCode(digits: "123456")
        
        for _ in 0..<PairingCode.maxAttempts {
            _ = code.validate("000000")
        }
        
        #expect(code.isValid == false)
        #expect(code.failedAttempts == PairingCode.maxAttempts)
        
        let lateValidation = code.validate("123456")
        #expect(lateValidation == false)
    }
    
    @Test("PairingCode expires after validity duration")
    func testExpiration() {
        let expiredCode = PairingCode(
            digits: "123456",
            expiresAt: Date().addingTimeInterval(-1)
        )
        
        #expect(expiredCode.isValid == false)
    }
    
    @Test("PairingCode displayString formatting")
    func testDisplayString() {
        let code = PairingCode(digits: "123456")
        
        #expect(code.displayString == "123 456")
    }
    
    @Test("PairingCode timeRemaining")
    func testTimeRemaining() {
        let futureCode = PairingCode(
            digits: "123456",
            expiresAt: Date().addingTimeInterval(300)
        )
        let expiredCode = PairingCode(
            digits: "123456",
            expiresAt: Date().addingTimeInterval(-10)
        )
        
        #expect(futureCode.timeRemaining > 0)
        #expect(expiredCode.timeRemaining == 0)
    }
}

@Suite("PSK Derivation Tests")
struct PSKDerivationTests {
    
    @Test("derivePSK returns 32-byte key")
    func testPSKLength() {
        let code = PairingCode(digits: "123456")
        let salt = Data("test-salt".utf8)
        
        let psk = derivePSK(from: code, salt: salt)
        
        #expect(psk.count == 32)
    }
    
    @Test("derivePSK is deterministic")
    func testPSKDeterministic() {
        let code = PairingCode(digits: "123456")
        let salt = Data("test-salt".utf8)
        
        let psk1 = derivePSK(from: code, salt: salt)
        let psk2 = derivePSK(from: code, salt: salt)
        
        #expect(psk1 == psk2)
    }
    
    @Test("derivePSK different codes produce different keys")
    func testPSKDifferentCodes() {
        let code1 = PairingCode(digits: "123456")
        let code2 = PairingCode(digits: "654321")
        let salt = Data("test-salt".utf8)
        
        let psk1 = derivePSK(from: code1, salt: salt)
        let psk2 = derivePSK(from: code2, salt: salt)
        
        #expect(psk1 != psk2)
    }
    
    @Test("derivePSK different salts produce different keys")
    func testPSKDifferentSalts() {
        let code = PairingCode(digits: "123456")
        let salt1 = Data("salt-1".utf8)
        let salt2 = Data("salt-2".utf8)
        
        let psk1 = derivePSK(from: code, salt: salt1)
        let psk2 = derivePSK(from: code, salt: salt2)
        
        #expect(psk1 != psk2)
    }
}
