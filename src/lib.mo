import ed "./ed25519";
import utils "./utils";


module {
    /**
    *   Lib Interface
    */
    public module ED25519 {
        /**
        *   Function getPublicKey(private key) -> (public key)
        *   
        */
        public func getPublicKey(privKey : [Nat8]) : [Nat8] {
            ed.ed25519.getPublicKeySync(#hex(#array privKey));
        };

        /**
        *   Function sign(message, private key) -> (signature)
        *
        */
        public func sign(message : [Nat8], privKey : [Nat8]) : [Nat8] {
            ed.ed25519.signSync(#array message, #array privKey);
        };

        /**
        *   Function verify(signature, message, public key) -> (true || false)
        *
        */
        public func verify(signature : [Nat8], message : [Nat8], pubKey : [Nat8]) : Bool {
            ed.ed25519.verifySync(#hex(#array signature), #array message, #hex(#array pubKey));
        };

        public func getSharedSecret() {
            // not implemented
        };
        /**
        *   Async func section (use if internal process call/use async function/canister/smartcontract)
        */
    };

    public module Utils {
        /**
        *   Function randomPrivateKey() -> (32 bytes)
        *
        */
        public func randomPrivateKey() : [Nat8] {
            utils.randomPrivateKey();
        };

        public func sha512(message : [[Nat8]]) : [Nat8] {
            utils.sha512(message);
        };

        public func bytesToHex(uint8a: [Nat8]): Text {
            utils.bytesToHex(uint8a);
        };

        public func hexToBytes(hex: Text): [Nat8] {
            utils.hexToBytes(hex);
        };
    };
}