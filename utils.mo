import T "types";
import CONST "const";
import FBlob "./generator/blob";
import Crypto "./crypto/crypto";

import Int8 "mo:base/Int8";
import Int32 "mo:base/Int32";
import Int64 "mo:base/Int64";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Char "mo:base/Char";
import Option "mo:base/Option";
import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Time "mo:base/Time";
import Blob "mo:base/Blob";

module Utils {
    type Hex = T.Hex;
    type PrivKey = T.PrivKey;
    type PubKey = T.PubKey;
    type SigType = T.SigType;

    func concatBytes(arrays: [[Nat8]]): [Nat8] {
        return Array.flatten<Nat8>(arrays);
    };

    // Convert between types
    // ---------------------
    func getHexes() : [Text] {
        let symbols = [
            '0', '1', '2', '3', '4', '5', '6', '7',
            '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
        ];
        let base : Nat8 = 0x10;
        func nat8ToText(u8: Nat8) : Text {
            let c1 = symbols[Nat8.toNat((u8/base))];
            let c2 = symbols[Nat8.toNat((u8%base))];
            return Char.toText(c1) # Char.toText(c2);
        };
        let array : [Text] = Array.tabulate<Text>(256, func i = nat8ToText(Nat8.fromNat(i)));
        return array;
    };

    public func int2Hex(x : Int) : Text {
        if (x == 0) return "0";
        var ret = "";
        var t = x;
        while (t > 0) {
            ret := (switch (t % 16) {
                case 0 { "0" };
                case 1 { "1" };
                case 2 { "2" };
                case 3 { "3" };
                case 4 { "4" };
                case 5 { "5" };
                case 6 { "6" };
                case 7 { "7" };
                case 8 { "8" };
                case 9 { "9" };
                case 10 { "a" };
                case 11 { "b" };
                case 12 { "c" };
                case 13 { "d" };
                case 14 { "e" };
                case 15 { "f" };
                case _ { "*" };
            }) # ret;
            t /= 16;
        };
        ret
    };

    public func bytesToHex(uint8a: [Nat8]): Text {
        // pre-caching improves the speed 6x
        // if (!(uint8a instanceof [Nat8])) throw new Error('[Nat8] expected');
        let hexes = getHexes();
        let hex = Array.foldRight<Nat8, Text>(uint8a, "", 
                                            func(x, acc) = hexes[Nat8.toNat(x)] # acc);
        return hex;
    };

    // Caching slows it down 2-3x
    func hexToBytes(hex: Text): [Nat8] {
        var map = HashMap.HashMap<Nat, Nat8>(1, Nat.equal, Hash.hash);
        // '0': 48 -> 0; '9': 57 -> 9
        for (num in Iter.range(48, 57)) {
            map.put(num, Nat8.fromNat(num-48));
        };
        // 'a': 97 -> 10; 'f': 102 -> 15
        for (lowcase in Iter.range(97, 102)) {
            map.put(lowcase, Nat8.fromNat(lowcase-97+10));
        };
        // 'A': 65 -> 10; 'F': 70 -> 15
        for (uppercase in Iter.range(65, 70)) {
            map.put(uppercase, Nat8.fromNat(uppercase-65+10));
        };
        let p = Iter.toArray(Iter.map(Text.toIter(hex),
                            func (x: Char) : Nat { Nat32.toNat(Char.toNat32(x)) }));
        var res : [var Nat8] = [var];       
        for (i in Iter.range(0, 31)) {            
            let a = Option.unwrap<Nat8>(map.get(p[i*2]));
            let b = Option.unwrap<Nat8>(map.get(p[i*2 + 1]));
            let c = 16*a + b;
            res := Array.thaw(Array.append(Array.freeze(res), Array.make(c)));
        };
        let result = Array.freeze(res);
        return result;
    };

    func hex2Int(hex : Text) : Int {
        var ret : Int = 0;
        var length = hex.size();
        for (i in hex.chars()) {
            length -= 1;
            ret += switch i {
                case ('A' or 'a') 10 * (16 ** length);
                case ('B'  or 'b') 11 * (16 ** length);
                case ('C'  or 'c') 12 * (16 ** length);
                case ('D'  or 'd') 13 * (16 ** length);
                case ('E' or 'e') 14 * (16 ** length);
                case ('F' or 'f') 15 * (16 ** length);
                case (c) {
                    let num = Int32.toInt(Int32.fromNat32(Char.toNat32(c) - 48));
                    num * (16 ** length);
                };
            };
        };
        return ret;
    };

    func numberTo32BytesBE(num: Int) : [Nat8] {
        let length = 32;
        let hex = int2Hex(num);
        var ret = hex;
        //  add padding 0
        Iter.iterate<Nat>(Iter.range(1, length * 2 - hex.size()), func(x, _index) {
            ret := "0" # ret;
        });
        return hexToBytes(ret);
    };

    public func numberTo32BytesLE(num: Int) : [Nat8] {
        return Array.reverse(numberTo32BytesBE(num));
    };

    // Little-endian check for first LE bit (last BE bit);
    public func edIsNegative(num: Int) : Bool {
        return (bitand(mod(num, null), CONST._1n)) == CONST._1n;
    };

    // Little Endian
    public func bytesToNumberLE(uint8a: [Nat8]): Int {
        return hex2Int(bytesToHex(Array.reverse(uint8a)));
    };

    // (2n ** 255n - 1n).toString(16)
    let MAX_255B : Int = 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    public func bytes255ToNumberLE(bytes: [Nat8]): Int {
        return mod(bitand(bytesToNumberLE(bytes), MAX_255B), null);
    };
        // -------------------------

    public func mod(a: Int, p: ?Int) : Int {
        let b = if (p == null) CONST.CURVE.P else Option.unwrap<Int>(p);
        let res = a % b;
        if (res >= CONST._0n)  res  else b + res;
    };

    // Note: this egcd-based invert is 50% faster than powMod-based one.
    // Inverses number over modulo
    public func invert(number: Int, m: ?Int): Int {
        let modulo = if (m == null) CONST.CURVE.P else Option.unwrap<Int>(m);
        if (number == CONST._0n or modulo <= CONST._0n) {
            Debug.trap("invert: expected positive integers, got n=${number} mod=${modulo}");
        };
        // Eucledian GCD https://brilliant.org/wiki/extended-euclidean-algorithm/
        var a = mod(number, ?modulo);
        var b = modulo;
        // prettier-ignore
        var x = CONST._0n;
        var y = CONST._1n;
        var u = CONST._1n;
        var v = CONST._0n;
        while (a != CONST._0n) {
            let q = b / a;
            let r = b % a;
            let m = x - u * q;
            let n = y - v * q;
            // prettier-ignore
            b := a;
            a := r;
            x := u;
            y := v;
            u := m;
            v := n;
        };
        let gcd = b;
        if (gcd != CONST._1n) Debug.trap("invert: does not exist");
        return mod(x, ?modulo);
    };

    /**
    * Takes a list of numbers, efficiently inverts all of them.
    * @param nums list of bigints
    * @param p modulo
    * @returns list of inverted bigints
    * @example
    * invertBatch([1n, 2n, 4n], 21n);
    * // => [1n, 11n, 16n]
    */
    public func invertBatch(nums: [Int], p: Int): [Int] {
        let numSize = Array.size(nums);
        // Walk from first to last, multiply them by each other MOD p
        var tmp : [var Int] = Array.init<Int>(numSize, 0);
        var i = 0;
        let lastMultiplied = Array.foldLeft<Int, Int>(
          nums,
          CONST._1n, // start at 1
          func(currentMul, value) : Int {
            i += 1;
            if (value == CONST._0n) return currentMul;
            tmp[i-1] := currentMul;
            return mod(currentMul * value, ?p);
          }
        );
        
        // Walk from last to first
        i := numSize;
        let inverted = invert(lastMultiplied, ?p);

        let f = Array.foldRight<Int, Int>(
          nums,
          inverted,
          func(value, currentMul) : Int {
            i -= 1;
            if (value == CONST._0n) return currentMul;
            tmp[i] := mod(currentMul * tmp[i], ?p);
            return mod(currentMul * value, ?p);
          }
        );
        return Array.freeze(tmp);
    };

    // Does x ^ (2 ^ power) mod p. pow2(30, 4) == 30 ^ (2 ^ 4)
    func pow2(x: Int, power: Int): Int {
        let { P } = CONST.CURVE;
        var res = x;
        var c = power;
        while (c > 0) {
            res *= res;
            res %= P;
            c -= 1;
        };
        return res;
    };

    // Power to (p-5)/8 aka x^(2^252-3)
    // Used to calculate y - the square root of y².
    // Exponentiates it to very big number.
    // We are unwrapping the loop because it's 2x faster.
    // (2n**252n-3n).toString(2) would produce bits [250x 1, 0, 1]
    // We are multiplying it bit-by-bit
    func pow_2_252_3(x: Int) : {pow_p_5_8 : Int; b2 : Int} {
        let { P } = CONST.CURVE;
        let _5n : Int = 5;
        let _10n : Int = 10;
        let _20n : Int = 20;
        let _40n : Int = 40;
        let _80n : Int = 80;
        let x2 = (x * x) % P;
        let b2 = (x2 * x) % P; // x^3, 11
        let b4 = (pow2(b2, CONST._2n) * b2) % P; // x^15, 1111
        let b5 = (pow2(b4, CONST._1n) * x) % P; // x^31
        let b10 = (pow2(b5, _5n) * b5) % P;
        let b20 = (pow2(b10, _10n) * b10) % P;
        let b40 = (pow2(b20, _20n) * b20) % P;
        let b80 = (pow2(b40, _40n) * b40) % P;
        let b160 = (pow2(b80, _80n) * b80) % P;
        let b240 = (pow2(b160, _80n) * b80) % P;
        let b250 = (pow2(b240, _10n) * b10) % P;
        let pow_p_5_8 = (pow2(b250, CONST._2n) * x) % P;
        // ^ To pow to (p+3)/8, multiply it by x.
        return { pow_p_5_8; b2 };
    };

    // Ratio of u to v. Allows us to combine inversion and square root. Uses algo from RFC8032 5.1.3.
    // letant-time
    // prettier-ignore
    public func uvRatio(u: Int, v: Int) : { isValid: Bool; x: Int } {
        let v3 = mod(v * v * v, null);                  // v³
        let v7 = mod(v3 * v3 * v, null);                // v⁷
        let pow = pow_2_252_3(u * v7).pow_p_5_8;
        var x = mod(u * v3 * pow, null);                  // (uv³)(uv⁷)^(p-5)/8
        let vx2 = mod(v * x * x, null);                 // vx²
        let root1 = x;                            // First root candidate
        let root2 = mod(x * CONST.SQRT_M1, null);             // Second root candidate
        let useRoot1 = vx2 == u;                 // If vx² = u (mod p), x is a square root
        let useRoot2 = vx2 == mod(-u, null);           // If vx² = -u, set x <-- x * 2^((p-1)/4)
        let noRoot = vx2 == mod(-u * CONST.SQRT_M1, null);   // There is no valid root, vx² = -u√(-1)
        if (useRoot1) x := root1;
        if (useRoot2 or noRoot) x := root2;          // We return root2 anyway, for let-time
        if (edIsNegative(x)) x := mod(-x, null);
        return { isValid = (useRoot1 or useRoot2); x = x };
    };

    // Calculates 1/√(number)
    public func invertSqrt(number: Int) : { isValid: Bool; x: Int } {
        return uvRatio(CONST._1n, number);
    };
    // Math end

    // Little-endian SHA512 with modulo n
    public func modlLE(hash: [Nat8]): Int {
        return mod(bytesToNumberLE(hash), ?CONST.CURVE.l);
    };

    public func equalBytes(b1: [Nat8], b2: [Nat8]) : Bool {
        // We don't care about timing attacks here
        if (Array.size(b1) != Array.size(b2)) {
            return false;
        };
        for (i in Iter.range(0, Array.size(b1) - 1)) {
          if (b1[i] != b2[i]) return false;
        };
        return true;
    };

    public func ensureBytes(hex: Hex, expectedLength: ?Nat): [Nat8] {
        // [Nat8].from() instead of hash.slice() because node.js Buffer
        // is instance of [Nat8], and its slice() creates **mutable** copy
        let bytes = switch hex {
            case (#array(h)) h;
            case (#string(h)) hexToBytes(h);
        };
        if (expectedLength != null and ?Array.size(bytes) != expectedLength) {
            Debug.trap("Expected ${expectedLength} bytes");
        };
        return bytes;
    };

    /**
    * Checks for num to be in range:
    * For strict == true:  `0 <  num < max`.
    * For strict == false: `0 <= num < max`.
    * Converts non-float safe numbers to bigints.
    */
    public func normalizeScalar(num: Int, max: Int, strict : ?Bool): Int {
        let st = switch strict {
            case (?s) s;
            case null true;
        };
        if (0 >= max) Debug.trap("Specify max value");
        if (num < max) {
            if (st) { // strict = true
                if (CONST._0n < num) return num;
            } else {
                if (CONST._0n <= num) return num;
            };
        };
        Debug.trap("Expected valid scalar: 0 < scalar < max");
    };

    public func adjustBytes25519(bytes: [Nat8]): [Nat8] {
        let bytesRet = Array.thaw<Nat8>(bytes);
        // Section 5: For X25519, in order to decode 32 random bytes as an integer scalar,
        // set the three least significant bits of the first byte
        bytesRet[0] := bytesRet[0] & 248; // 0b1111_1000
        // and the most significant bit of the last to zero,
        bytesRet[31] := bytesRet[31] & 127; // 0b0111_1111
        // set the second most significant bit of the last byte to 1
        bytesRet[31] := bytesRet[31] | 64; // 0b0100_0000
        return Array.freeze(bytesRet);
    };

    public func decodeScalar25519(n: Hex): Int {
        // and, finally, decode as little-endian.
        // This means that the resulting integer is of the form 2 ^ 254 plus eight times a value between 0 and 2 ^ 251 - 1(inclusive).
        return bytesToNumberLE(adjustBytes25519(ensureBytes(n, ?32)));
    };

    public func checkPrivateKey(key: PrivKey) : [Nat8] {
        // Normalize bigint / number / string to [Nat8]
        let keyRet = switch key {
            case (#hex(kh)) ensureBytes(kh, null);
            case (#number(k)) numberTo32BytesBE(normalizeScalar(k, CONST.POW_2_256, null));
            case (#bigint(k)) numberTo32BytesBE(normalizeScalar(k, CONST.POW_2_256, null));
        };
        if (Array.size(keyRet) != 32) {
            Debug.trap("Expected 32 bytes");
        };
        return keyRet;
    };
    // function syncGuard() {
    // }

    // public let sync = {
    // /** Convenience method that creates public key and other stuff. RFC8032 5.1.5 */
    // getExtendedPublicKey = getExtendedPublicKeySync;
    // /** Calculates ed25519 public key. RFC8032 5.1.5 */
    // getPublicKey: getPublicKeySync,
    // /** Signs message with privateKey. RFC8032 5.1.6 */
    // sign: signSync,
    // /** Verifies ed25519 signature against message and public key. */
    // verify: verifySync,
    // };

    // Enable precomputes. Slows down first publicKey computation by 20ms.
    // Point.BASE._setWindowSize(?8);

    // CONST.CURVE25519-related code
    // CONST.CURVE equation: v^2 = u^3 + A*u^2 + u
    // https://datatracker.ietf.org/doc/html/rfc7748

    // cswap from RFC7748
    func cswap(swap: Int, x_2: Int, x_3: Int): (Int, Int) {
        let dummy = mod(swap * (x_2 - x_3), null);
        let x_2_ret = mod(x_2 - dummy, null);
        let x_3_ret = mod(x_3 + dummy, null);
        return (x_2_ret, x_3_ret);
    };

    // x25519 from 4
    /**
    *
    * @param pointU u coordinate (x) on Montgomery CONST.CURVE 25519
    * @param scalar by which the point would be multiplied
    * @returns new Point on Montgomery CONST.CURVE
    */
    public func montgomeryLadder(pointU: Int, scalar: Int): Int {
        let { P } = CONST.CURVE;
        let u = normalizeScalar(pointU, P, null);
        // Section 5: Implementations MUST accept non-canonical values and process them as
        // if they had been reduced modulo the field prime.
        let k = normalizeScalar(scalar, P, null);
        // The letant a24 is (486662 - 2) / 4 = 121665 for CONST.CURVE25519/X25519
        let a24 : Int = 121665;
        let x_1 = u;
        var x_2 = CONST._1n;
        var z_2 = CONST._0n;
        var x_3 = u;
        var z_3 = CONST._1n;
        var swap = CONST._0n;
        var sw: (Int, Int) = (0,0);

        for (t in Iter.revRange(254, 0)) {
            let k_t = bitand(bitrightshift(k, Int.abs(t)), CONST._1n); // (k >> t) & CONST._1n;
            swap := bitxor(swap,  k_t);
            sw := cswap(swap, x_2, x_3);
            x_2 := sw.0;
            x_3 := sw.1;
            sw := cswap(swap, z_2, z_3);
            z_2 := sw.0;
            z_3 := sw.1;
            swap := k_t;

            let A = x_2 + z_2;
            let AA = mod(A * A, null);
            let B = x_2 - z_2;
            let BB = mod(B * B, null);
            let E = AA - BB;
            let C = x_3 + z_3;
            let D = x_3 - z_3;
            let DA = mod(D * A, null);
            let CB = mod(C * B, null);
            let dacb = DA + CB;
            let da_cb = DA - CB;
            x_3 := mod(dacb * dacb, null);
            z_3 := mod(x_1 * mod(da_cb * da_cb, null), null);
            x_2 := mod(AA * BB, null);
            z_2 := mod(E * (AA + mod(a24 * E, null)), null);
        };

        sw := cswap(swap, x_2, x_3);
        x_2 := sw.0;
        x_3 := sw.1;
        sw := cswap(swap, z_2, z_3);
        z_2 := sw.0;
        z_3 := sw.1;
        let { pow_p_5_8; b2 } = pow_2_252_3(z_2);
        // x^(p-2) aka x^(2^255-21)
        let xp2 = mod(pow2(pow_p_5_8, 3) * b2, null);
        return mod(x_2 * xp2, null);
    };

    public func encodeUCoordinate(u: Int): [Nat8] {
        return numberTo32BytesLE(mod(u, null));
    };

    public func decodeUCoordinate(uEnc: Hex): Int {
        let u = Array.thaw<Nat8>(ensureBytes(uEnc, ?32));
        // Section 5: When receiving such an array, implementations of X25519
        // MUST mask the most significant bit in the final byte.
        u[31] &= 127; // 0b0111_1111
        return bytesToNumberLE(Array.freeze(u));
    };

    // The 8-torsion subgroup ℰ8.
    // Those are "buggy" points, if you multiply them by 8, you'll receive Point.ZERO.
    // Ported from CONST.CURVE25519-dalek.
    let TORSION_SUBGROUP = [
        "0100000000000000000000000000000000000000000000000000000000000000",
        "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac037a",
        "0000000000000000000000000000000000000000000000000000000000000080",
        "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc05",
        "ecffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff7f",
        "26e8958fc2b227b045c3f489f2ef98f0d5dfac05d3c63339b13802886d53fc85",
        "0000000000000000000000000000000000000000000000000000000000000000",
        "c7176a703d4dd84fba3c0b760d10670f2a2053fa2c39ccc64ec7fd7792ac03fa",
    ];

    /**
    * Can take 40 or more bytes of uniform input e.g. from CSPRNG or KDF
    * and convert them into private scalar, with the modulo bias being neglible.
    * As per FIPS 186 B.4.1.
    * Not needed for ed25519 private keys. Needed if you use scalars directly (rare).
    * @param hash hash output from sha512, or a similar function
    * @returns valid private scalar
    */
    func hashToPrivateScalar(hash: Hex): Int {
        let h = ensureBytes(hash, null);
        if (Array.size(h) < 40 or Array.size(h) > 1024) {
            Debug.trap("Expected 40-1024 bytes of private key as per FIPS 186");
        };
        return mod(bytesToNumberLE(h), ?(CONST.CURVE.l - CONST._1n)) + CONST._1n;
    };

    func createGenerator(): T.Generator<Nat> {
      let seed: Nat = Int.abs(Time.now());
      let prime = 456209410580464648418198177201;
      let prime2 = 4451889979529614097557895687536048212109;
      var prev = seed;
      {
        next = func(): Nat {
          let cur = (prev * prime + 5) % prime2;
          prev := cur;
          cur;
        };
      };
    };

    func randomBytes(blength: ?Nat): [Nat8] {
        let bytesLength = switch blength {
          case null 32;
          case (?l) l;
        };
        let gen = createGenerator();
        let blob = FBlob.FBlob(gen);
        let b = blob.random(bytesLength);
        Blob.toArray(b);
    };
    /**
    * ed25519 private keys are uniform 32-bit strings. We do not need to check for
    * modulo bias like we do in noble-secp256k1 randomPrivateKey()
    */
    public func randomPrivateKey(): [Nat8] {
        return randomBytes(?32);
    };
    /** Shortcut method that calls native async implementation of sha512 */
    public func sha512(messages: [[Nat8]]): [Nat8] {
        let message = concatBytes(messages);
        let b = Crypto.fromIter(#sha512, Iter.fromArray(message));
        return Blob.toArray(b);
    };

    type Sha512FnSync = {
        #undefined;
        #function : ([[Nat8]]) -> [Nat8];
    };

    let _sha512Sync: Sha512FnSync = #function sha512;

    public func sha512s(messages : [[Nat8]]) : [Nat8] {
        // if (typeof _sha512Sync !== 'function')
        //     throw new Error('utils.sha512Sync must be set to use sync methods');
        switch _sha512Sync {
            case (#function(f)) f(messages);
            case (_) Debug.trap("utils.sha512Sync must be set to use sync methods");
        };
    };

    //////////////// BIT PROCESSING
    // convert int to binary array
    func int2bin(num : Int) : [Bool] {
        if (num == 0) {
            return [false];
        };
        var ret = Buffer.Buffer<Bool>(0);
        var n = num;
        while (n > 0) {
            let val = ((n % 2) == 1);
            ret.add(val);
            n /= 2;
        };
        return Buffer.toArray(ret);
    };

    // convert binary array to int
    func bin2int(bin : [Bool]) : Int {
        var ret : Int = 0;
        for (i in Iter.range(0, Array.size(bin) - 1)) {
            if (bin[i]) {
                ret := ret + (2 ** i);
            };
        };
        return ret;
    };

    // handle ubigint 2^255
    // in case process signed big int implêment some func => flip bit >> add 1 >> fill pading 1.. 
    public func bitand(st : Int, nd : Int) : Int {
        let first = int2bin(st);
        let second = int2bin(nd);
        let size1st = Array.size(first);
        let size2nd = Array.size(second);
        let max = if (size1st > size2nd) size1st else size2nd;
        var ret = Buffer.Buffer<Bool>(0);
        for (i in Iter.range(0, max - 1)) {
            let bit = if (i >= size1st or i >= size2nd) false else first[i] and second[i];
            ret.add(bit);
        };
        return bin2int(Buffer.toArray<Bool>(ret));
    };

    // xor bit ubigint - 1^1 = 0^0 = 0, 1^0 = 0^1 = 1
    public func bitxor(st : Int, nd : Int) : Int {
        let first = int2bin(st);
        let second = int2bin(nd);
        let size1st = Array.size(first);
        let size2nd = Array.size(second);
        let max = if (size1st > size2nd) size1st else size2nd;
        var ret : [Bool] = [];
        for (i in Iter.range(0, max - 1)) {
            let bit = if (i >= size1st) {
                not(second[i] == false)
            } else if (i >= size2nd) {
                not(first[i] == false)
            } else {
                not(first[i] == second[i])
            };
            ret := Array.append<Bool>(ret, [bit]);
        };
        return bin2int(ret);
    };

    // bit left shift <<
    public func bitleftshift(num : Int, move : Nat) : Int {
        var binary = int2bin(num);
        let size = Array.size(binary);
        var count = 0;
        while (count != move) {
            binary := Array.append([false], binary);
            count += 1;
        };
        return bin2int(binary);
    };

    // bit right shift >>
    public func bitrightshift(num : Int, move : Nat) : Int {
        let binary = int2bin(num);
        let size = Array.size(binary);
        var count = 0;
        var ret : [Bool] = [];
        if (move < size) {
            for (i in Iter.range(move, size - 1)) {
                ret := Array.append<Bool>(ret, [binary[i]]);
            };
        };
        while (count != move) {
            let bit = if (num > 0) false else true; 
            ret := Array.append(ret, [bit]);
            count += 1;
        };
        return bin2int(ret);
    };

    // bit not : 
    public func bitnot(num : Int) : Int {
        if (num == 0) return -1;
        if (num > 0) return -(num + 1);
        return -(num - 1);
    };

    func bitflip(bin : [Bool], reverse : Bool) : [Bool] {
        var bbuff = Buffer.fromArray<Bool>(bin);
        bbuff := Buffer.map<Bool, Bool>(bbuff, func (x) { not x });
        let ret = if (reverse) {
                    Buffer.reverse<Bool>(bbuff);
                    Buffer.toArray<Bool>(bbuff); 
                } else {
                    Buffer.toArray<Bool>(bbuff);
                };
        return ret;
    };

    func bitaddone(bin : [Bool]) : [Bool] {
        var bbuff = Buffer.fromArray<Bool>(bin);
        var add = true;
        bbuff := Buffer.map<Bool, Bool>(bbuff, func (x) {
                    if (add) {
                        if (not x) {
                            add := not add;
                        };
                        not x;
                    } else {
                        x;
                    }
                });
        return Buffer.toArray<Bool>(bbuff);
    };

    // example : 5 -> -5
    func bitpos2neg(bin : [Bool]) : [Bool] {
        return bitaddone(bitflip(bin, false));
    };
}