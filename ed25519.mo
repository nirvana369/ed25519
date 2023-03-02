import Utils "utils";
import T "types";
import Point "point";

module {

    let BASE_POINT_U : T.Hex = #string "0900000000000000000000000000000000000000000000000000000000000000";

    /** crypto_scalarmult aka getSharedSecret */
    public func scalarMult(privateKey: T.Hex, publicKey: T.Hex): [Nat8] {
        let u = decodeUCoordinate(publicKey);
        let p = decodeScalar25519(privateKey);
        let pu = montgomeryLadder(u, p);
        // The result was not contributory
        // https://cr.yp.to/ecdh.html#validate
        if (pu == _0n) Debug.trap("Invalid private or public key received");
        return encodeUCoordinate(pu);
    };

    /** crypto_scalarmult_base aka getPublicKey */
    public func scalarMultBase(privateKey: T.Hex): [Nat8] {
        return scalarMult(privateKey, BASE_POINT_U);
    };


    public func fromPrivateKey(privateKey: T.PrivKey) : Point {
        return (getExtendedPublicKey(privateKey)).point;
    };

    // Takes 64 bytes
    func getKeyFromHash(hashed: [Nat8]) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: Point;
                                                pointBytes: [Nat8]
                                            }
    {
        let (firstBytes, secondBytes) = Buffer.split<Nat>(bytes, 32);
        // First 32 bytes of 64b uniformingly random input are taken,
        // clears 3 bits of it to produce a random field element.
        let head = adjustBytes25519(firstBytes);
        // Second 32 bytes is called key prefix (5.1.6)
        let prefix = secondBytes;
        // The actual private scalar
        let scalar = modlLE(head);
        // Point on Edwards CONST.CURVE aka public key
        let point = Point.BASE.multiply(scalar);
        let pointBytes = point.toRawBytes();
        return {    head=head;
                    prefix=prefix;
                    scalar=scalar;
                    point=point;
                    pointBytes=pointBytes 
                };
    };

    /** Convenience method that creates public key and other stuff. RFC8032 5.1.5 */
    public func getExtendedPublicKey(key: PrivKey) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: Point;
                                                pointBytes: [Nat8]
                                            } {
        return getKeyFromHash(await sha512(checkPrivateKey(key)));
    };


    func getExtendedPublicKeySync(key: PrivKey) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: Point;
                                                pointBytes: [Nat8]
                                            } {
        return getKeyFromHash(sha512s(checkPrivateKey(key)));
    };

    // Helper functions because we have async and sync methods.
    func prepareVerification(sig: SigType, messageHex: Hex, publicKey: PubKey) : {
        r : Point; s : Int; pub: Point; msg: [Nat8];
    } {
        let message = ensureBytes(messageHex, null);
        // When hex is passed, we check public key fully.
        // When Point instance is passed, we assume it has already been checked, for performance.
        // If user passes Point/Sig instance, we assume it has been already verified.
        // We don't check its equations for performance. We do check for valid bounds for s though
        // We always check for: a) s bounds. b) hex validity
        let publicKeyAsPoint = switch publicKey {
            case (#point(p)) return p;
            case (#hex(h)) return Point.fromHex(h, false);
        };
        let { r : Point; s : Int } = switch sig {
            case (#array(arr)) sig.assertValidity();
            case (#hex(h)) Signature.fromHex(h);
        };
        
        let SB = ExtendedPoint.BASE.multiplyUnsafe(s);
        return { r; s; SB; publicKeyAsPoint; message };
    };

    func finishVerification(publicKey: Point, r: Point, SB: ExtendedPoint, hashed: [Nat8]) {
        let k = modlLE(hashed);
        let kA = ExtendedPoint.fromAffine(publicKey).multiplyUnsafe(k);
        let RkA = ExtendedPoint.fromAffine(r).add(kA);
        // [8][S]B = [8]R + [8][k]A'
        return RkA.subtract(SB).multiplyUnsafe(CONST.CURVE.h).equals(ExtendedPoint.ZERO);
    };

    /**
    * Verifies ed25519 signature against message and public key.
    * An extended group equation is checked.
    * RFC8032 5.1.7
    * Compliant with ZIP215:
    * 0 <= sig.R/publicKey < 2**256 (can be >= CONST.CURVE.P)
    * 0 <= sig.s < l
    * Not compliant with RFC8032: it's not possible to comply to both ZIP & RFC at the same time.
    */
    public func verify(sig: SigType, message: Hex, publicKey: PubKey): async Bool {
        let { r; SB; msg; pub } = prepareVerification(sig, message, publicKey);
        let hashed = sha512(r.toRawBytes(), pub.toRawBytes(), msg);
        return finishVerification(pub, r, SB, hashed);
    };

    func verifySync(sig: SigType, message: Hex, publicKey: PubKey): Bool {
        let { r; SB; msg; pub } = prepareVerification(sig, message, publicKey);
        let hashed = sha512s(r.toRawBytes(), pub.toRawBytes(), msg);
        return finishVerification(pub, r, SB, hashed);
    };

    /**
    * We're doing scalar multiplication (used in getPublicKey etc) with precomputed BASE_POINT
    * values. This slows down first getPublicKey() by milliseconds (see Speed section),
    * but allows to speed-up subsequent getPublicKey() calls up to 20x.
    * @param windowSize 2, 4, 8, 16
    */
    public func precompute(windowSize : ?Nat, p : ?Point): Point {
        let point = if (p == null) Point.BASE else Option.unwrap<Point>(p);
        let cached = if (Point.equals(point, Point.BASE)) point else Point.Point(point.x, point.y);
        cached._setWindowSize(windowSize);
        cached.multiply(CONST._2n);
        return cached;
    };

    /**
    * Calculates ed25519 public key. RFC8032 5.1.5
    * 1. private key is hashed with sha512, then first 32 bytes are taken from the hash
    * 2. 3 least significant bits of the first byte are cleared
    */
    public func getPublicKey(privateKey: PrivKey): async [Nat8] {
        return (await getExtendedPublicKey(privateKey)).pointBytes;
    };

    func getPublicKeySync(privateKey: PrivKey): [Nat8] {
        return getExtendedPublicKeySync(privateKey).pointBytes;
    };

    /** Signs message with privateKey. RFC8032 5.1.6 */
    public func sign(messageHex: Hex, privateKey: Hex): async [Nat8] {
        let message = ensureBytes(messageHex, null);
        let { prefix; scalar; pointBytes } = await getExtendedPublicKey(privateKey);
        let r = modlLE(sha512(prefix, message)); // r = hash(prefix + msg)
        let R = Point.BASE.multiply(r); // R = rG
        let k = modlLE(sha512(R.toRawBytes(), pointBytes, message)); // k = hash(R+P+msg)
        let s = mod(r + k * scalar, ?CONST.CURVE.l); // s = r + kp
        return Signature(R, s).toRawBytes();
    };

    func signSync(messageHex: Hex, privateKey: Hex): [Nat8] {
        let message = ensureBytes(messageHex, null);
        let { prefix; scalar; pointBytes } = getExtendedPublicKeySync(privateKey);
        let r = modlLE(sha512s(prefix, message)); // r = hash(prefix + msg)
        let R = Point.BASE.multiply(r); // R = rG
        let k = modlLE(sha512s(R.toRawBytes(), pointBytes, message)); // k = hash(R+P+msg)
        let s = mod(r + k * scalar, ?CONST.CURVE.l); // s = r + kp
        return new Signature(R, s).toRawBytes();
    };

    /**
    * Calculates X25519 DH shared secret from ed25519 private & public keys.
    * CONST.CURVE25519 used in X25519 consumes private keys as-is, while ed25519 hashes them with sha512.
    * Which means we will need to normalize ed25519 seeds to "hashed repr".
    * @param privateKey ed25519 private key
    * @param publicKey ed25519 public key
    * @returns X25519 shared key
    */
    public func getSharedSecret(privateKey: PrivKey, publicKey: Hex): async [Nat8] {
        let { head } = await getExtendedPublicKey(privateKey);
        let u = Point.fromHex(publicKey).toX25519();
        return CONST.CURVE25519.scalarMult(head, u);
    };
}