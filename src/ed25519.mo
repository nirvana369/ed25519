import T "types";
import CONST "const";
import Utils "utils";

import Array "mo:base/Array";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Int8 "mo:base/Int8";
import Int16 "mo:base/Int16";
import Int "mo:base/Int";
import Nat8 "mo:base/Nat8";
import Nat16 "mo:base/Nat16";


module C_Point {

    // Base point aka generator
    // public_key = Point.BASE * private_key
    public let BASE: T.Point = { x = CONST.CURVE.Gx; y = CONST.CURVE.Gy; windowSize = ?8};
    // Identity point aka point at infinity
    // point = point + zero_point
    public let ZERO: T.Point = { x =CONST._0n; y = CONST._1n; windowSize = ?8};

    public func getBase() : Point {
        let p = Point(CONST.CURVE.Gx, CONST.CURVE.Gy);
        p;
    };

    public func getZero() : Point {
        let p = Point(CONST._0n, CONST._1n);
        p;
    };

    // Converts hash string or Uint8Array to Point.
    // Uses algo from RFC8032 5.1.3.
    public func fromHex(h: T.Hex, strict : ?Bool) : Point {
        let strictMode = switch strict {
            case (?s) s;
            case null true;
        };
        let { d; P } = CONST.CURVE;
        let hex = Utils.ensureBytes(h, ?32);
        // 1.  First, interpret the string as an integer in little-endian
        // representation. Bit 255 of this number is the least significant
        // bit of the x-coordinate and denote this value x_0.  The
        // y-coordinate is recovered simply by clearing this bit.  If the
        // resulting value is >= p, decoding fails.
        let normed = Array.thaw<Nat8>(hex);
        normed[31] := Nat8.fromIntWrap(Int16.toInt(Int16.fromNat16(Nat16.fromNat(Nat8.toNat(hex[31]))) & Int16.fromIntWrap(-129))); // not(0x80) = -129
        let y = Utils.bytesToNumberLE(Array.freeze(normed));

        if (strictMode and y >= P) Debug.trap("Expected 0 < hex < P");
        if ((not strictMode) and y >= CONST.POW_2_256) Debug.trap("Expected 0 < hex < 2**256");

        // 2.  To recover the x-coordinate, the CONST.CURVE equation implies
        // x² = (y² - 1) / (d y² + 1) (mod p).  The denominator is always
        // non-zero mod p.  Let u = y² - 1 and v = d y² + 1.
        let y2 = Utils.mod(y * y, null);
        let u = Utils.mod(y2 - CONST._1n, null);
        let v = Utils.mod(d * y2 + CONST._1n, null);
        let res : { isValid: Bool; x : Int } = Utils.uvRatio(u, v);
        if (res.isValid == false) Debug.trap("Point.fromHex: invalid y coordinate");

        // 4.  Finally, use the x_0 bit to select the right square root.  If
        // x = 0, and x_0 = 1, decoding fails.  Otherwise, if x_0 != x mod
        // 2, set x <-- p - x.  Return the decoded point (x,y).
        let isXOdd = (Utils.bitand(res.x, CONST._1n)) == CONST._1n;
        let isLastByteOdd = (hex[31] & 0x80) != 0;
        let x = if (isLastByteOdd != isXOdd) {
            Utils.mod(-res.x, null);
        } else {
            res.x;
        };
        return Point(x, y);
    };

    public func mapTPoint2Point(p : T.Point) : Point {
        let point = C_Point.Point(p.x, p.y);
        point._setWindowSize(p.windowSize);
        return point;
    };

    public class Point(xP: Int, yP: Int) = this {
        
        public let x = xP;
        public let y = yP;
        // We calculate precomputes for elliptic CONST.CURVE point multiplication
        // using windowed method. This specifies window size and
        // stores precomputed values. Usually only base point would be precomputed.
        var _WINDOW_SIZE: ?Nat = ?8;

        // // "Private method", don't use it directly.
        public func _setWindowSize(windowSize: ?Nat) {
            _WINDOW_SIZE := windowSize;
        };

        public func getWindowSize() : ?Nat {
            return _WINDOW_SIZE;
        };

        public func get() : T.Point {
            return {
                x = x;
                y = y;
                windowSize = _WINDOW_SIZE;
            };
        };

        // There can always be only two x values (x, -x) for any y
        // When compressing point, it's enough to only store its y coordinate
        // and use the last byte to encode sign of x.
        public func toRawBytes(): [Nat8] {
            let bytes = Array.thaw<Nat8>(Utils.numberTo32BytesLE(y));
            bytes[31] |= if (Utils.bitand(x, CONST._1n) == CONST._1n) 0x80 else 0;
            return Array.freeze(bytes);
        };

        // Same as toRawBytes, but returns string.
        public func toHex(): Text {
            return Utils.bytesToHex(toRawBytes());
        };

        /**
        * Converts to Montgomery; aka x coordinate of CONST.CURVE25519.
        * We don't have fromX25519, because we don't know sign.
        *
        * ```
        * u, v: CONST.CURVE25519 coordinates
        * x, y: ed25519 coordinates
        * (u, v) = ((1+y)/(1-y), sqrt(-486664)*u/x)
        * (x, y) = (sqrt(-486664)*u/v, (u-1)/(u+1))
        * ```
        * https://blog.filippo.io/using-ed25519-keys-for-encryption
        * @returns u coordinate of CONST.CURVE25519 point
        */
        public func toX25519(): [Nat8] {
            let u = Utils.mod((CONST._1n + y) * Utils.invert(CONST._1n - y, null), null);
            return Utils.numberTo32BytesLE(u);
        };

        public func isTorsionFree(): Bool {
            return C_ExtendedPoint.fromAffine(this).isTorsionFree();
        };

        public func negate() : Point {
            return Point(Utils.mod(-x, null), y);
        };

        public func add(other: Point) : Point {
            return C_ExtendedPoint.fromAffine(this).add(C_ExtendedPoint.fromAffine(other)).toAffine(null);
        };

        public func subtract(other: Point) : Point {
            return add(other.negate());
        };

        /**
        * Constant time multiplication.
        * @param scalar Big-Endian number
        * @returns new point
        */
        public func multiply(scalar: Int): Point {
            return C_ExtendedPoint.fromAffine(this).multiply(scalar, ?this).toAffine(null);
        };

        public func equals(b: Point): Bool {
            return (this.x == b.x and this.y == b.y);
        };
    };
};

module C_ExtendedPoint {
    
    // public let BASE : T.ExtendedPoint = {x = CONST.CURVE.Gx; y = CONST.CURVE.Gy; z =  CONST._1n; t = Utils.mod(CONST.CURVE.Gx * CONST.CURVE.Gy, null)};
    // public let ZERO : T.ExtendedPoint = {x = CONST._0n; y = CONST._1n; z = CONST._1n; t = CONST._0n};
        
    public func getBase() : ExtendedPoint {
        return ExtendedPoint(CONST.CURVE.Gx,CONST.CURVE.Gy, CONST._1n, Utils.mod(CONST.CURVE.Gx * CONST.CURVE.Gy, null));
    };
    public func getZero() : ExtendedPoint {
        return ExtendedPoint(CONST._0n, CONST._1n, CONST._1n, CONST._0n);
    };

    public func legacyRist() : () {
        Debug.trap("Legacy method: switch to RistrettoPoint");
    };

    public func assertExtPoint(other: ExtendedPoint) {
        Debug.trap("assertExtPoint not implemented!");
    };

    public func constTimeNegate(condition: Bool, item: ExtendedPoint) :  ExtendedPoint {
        let neg = item.negate();
        return if (condition) neg else item;
    };

    public func fromAffine(p: C_Point.Point): ExtendedPoint {
        if (C_Point.getZero().equals(p)) return getZero();
        return ExtendedPoint(p.x, p.y, CONST._1n, Utils.mod(p.x * p.y, null));
    };

    public func maplPoint2lTExPoint(lep : [ExtendedPoint]) : [T.ExtendedPoint] {
        Array.map<ExtendedPoint, T.ExtendedPoint>(lep, func a = a.get());
    };

    public func maplTExPoint2lPoint(lep : [T.ExtendedPoint]) : [ExtendedPoint] {
        Array.map<T.ExtendedPoint, ExtendedPoint>(lep, func a = ExtendedPoint(a.x, a.y, a.z, a.t));
    };

    public func mapPoint2TRecord(p : C_Point.Point, lep : [ExtendedPoint]) : T.Record {
        let k = p.get();
        let v = maplPoint2lTExPoint(lep);
        return {
            key = k;
            value = v;
        };
    };

    public class ExtendedPoint(
                                xP : Int,
                                yP : Int,
                                zP : Int,
                                tP : Int) = this {

        

        public let x = xP;
        public let y = yP;
        public let z = zP;
        public let t = tP;
        
        public func get() : T.ExtendedPoint {
            return {
                x = x;
                y = y;
                z = z;
                t = t;
            };
        };
        // Takes a bunch of Jacobian Points but executes only one
        // invert on all of them. invert is very slow operation,
        // so this improves performance massively.
        func toAffineBatch(points: [ExtendedPoint]): [C_Point.Point] {
            let toInv = Utils.invertBatch(Array.map<ExtendedPoint, Int>(points, func p = p.z), CONST.CURVE.P);
            var i = 0;
            let ret = Array.map<ExtendedPoint, C_Point.Point>(points, func p : C_Point.Point {
                let tmp = p.toAffine(?toInv[i]);
                i += 1;
                tmp;
            });
            return ret;
        };

        public func normalizeZ(points: [ExtendedPoint]): [ExtendedPoint] {
            return Array.map<C_Point.Point, ExtendedPoint>(toAffineBatch(points), func p = fromAffine(p));
        };

        // Compare one point to another.
        public func equals(other: ExtendedPoint): Bool {
            // assertExtPoint(other);
            let { x= X1; y= Y1; z= Z1 } = this;
            let { x= X2; y= Y2; z= Z2 } = other;
            let X1Z2 = Utils.mod(X1 * Z2, null);
            let X2Z1 = Utils.mod(X2 * Z1, null);
            let Y1Z2 = Utils.mod(Y1 * Z2, null);
            let Y2Z1 = Utils.mod(Y2 * Z1, null);
            return X1Z2 == X2Z1 and Y1Z2 == Y2Z1;
        };

        // Inverses point to one corresponding to (x, -y) in Affine coordinates.
        public func negate(): ExtendedPoint {
            return ExtendedPoint(Utils.mod(-this.x, null), this.y, this.z, Utils.mod(-this.t, null));
        };

        // Fast algo for doubling Extended Point
        // https://hyperelliptic.org/EFD/g1p/auto-twisted-extended.html#doubling-dbl-2008-hwcd
        // Cost: 4M + 4S + 1*a + 6add + 1*2.
        public func double(): ExtendedPoint {
            let { x = X1; y = Y1; z = Z1 } = this;
            let { a } = CONST.CURVE;
            let A = Utils.mod(X1 * X1, null);
            let B = Utils.mod(Y1 * Y1, null);
            let C = Utils.mod(CONST._2n * Utils.mod(Z1 * Z1, null), null);
            let D = Utils.mod(a * A, null);
            let x1y1 = X1 + Y1;
            let E = Utils.mod(Utils.mod(x1y1 * x1y1, null) - A - B, null);
            let G = D + B;
            let F = G - C;
            let H = D - B;
            let X3 = Utils.mod(E * F, null);
            let Y3 = Utils.mod(G * H, null);
            let T3 = Utils.mod(E * H, null);
            let Z3 = Utils.mod(F * G, null);
            return ExtendedPoint(X3, Y3, Z3, T3);
        };

        // Fast algo for adding 2 Extended Points when curve's a=-1.
        // http://hyperelliptic.org/EFD/g1p/auto-twisted-extended-1.html#addition-add-2008-hwcd-4
        // Cost: 8M + 8add + 2*2.
        // Note: It does not check whether the `other` point is valid.
        public func add(other: ExtendedPoint) : ExtendedPoint {
            // assertExtPoint(other);
            let { x = X1; y = Y1; z = Z1; t = T1 } = this;
            let { x = X2; y = Y2; z = Z2; t = T2 } = other;
            let A = Utils.mod((Y1 - X1) * (Y2 + X2), null);
            let B = Utils.mod((Y1 + X1) * (Y2 - X2), null);
            let F = Utils.mod(B - A, null);
            if (F == CONST._0n) return this.double(); // Same point.
            let C = Utils.mod(Z1 * CONST._2n * T2, null);
            let D = Utils.mod(T1 * CONST._2n * Z2, null);
            let E = D + C;
            let G = B + A;
            let H = D - C;
            let X3 = Utils.mod(E * F, null);
            let Y3 = Utils.mod(G * H, null);
            let T3 = Utils.mod(E * H, null);
            let Z3 = Utils.mod(F * G, null);
            return ExtendedPoint(X3, Y3, Z3, T3);
        };

        public func subtract(other: ExtendedPoint): ExtendedPoint {
            return this.add(other.negate());
        };

        private func precomputeWindow(W: Int): [ExtendedPoint] {
            let windows = 1 + 256 / W;
            let points = Buffer.Buffer<ExtendedPoint>(0);
            var p: ExtendedPoint = this;
            var base = p;
            var window = 0;
            while (window < windows) {
                base := p;
                points.add(base);
                var i = 1;
                while (i < 2 ** (W - 1)) {
                    base := base.add(p);
                    points.add(base);
                    i += 1;
                };
                p := base.double();
                window += 1;
            };
            return Buffer.toArray<ExtendedPoint>(points);
        };

        private func wNAF(n: Int, affPoint: ?C_Point.Point): ExtendedPoint {
            let affinePoint : C_Point.Point = switch affPoint {
                case (?p) p;
                case null C_Point.getBase();
            };
            let W = switch (affinePoint.getWindowSize()) {
                case null 1;
                case (?s) s;
            };
            if (256 % W != 0) {
                Debug.trap("Point#wNAF: Invalid precomputation window, must be power of 2");
            };
            

            // warning ! need pre calculate to faster
            var precomputes = normalizeZ(precomputeWindow(W));

            // var precomputes = switch (S.get(preprocess, C_Point.mapPoint2TPoint(affinePoint))) {
            //     case null {
            //         var lep = precomputeWindow(W);
            //         if (W != 1) {
            //             lep := normalizeZ(lep);
            //             preprocess := S.put(preprocess, C_Point.mapPoint2TPoint(affinePoint), maplPoint2lTExPoint(lep));
            //         };
            //         lep;
            //     };
            //     case (?r) maplTExPoint2lPoint(r.value);
            // };

            var p = getZero();
            var f = getBase();

            let windows = 1 + 256 / W;
            let windowSize = 2 ** (W - 1);
            let mask : Int = 2 ** W - 1; // Create mask with W ones: 0b1111 for W=4 etc.
            let maxNumber = 2 ** W;
            let shiftBy = W;

            var window = 0;
            var tmp = n;
            while (window < windows) {
                let offset : Int = window * windowSize;
                // Extract W bits.
                var wbits = Utils.bitand(tmp, mask); //Number(n & mask);

                // Shift number by W bits.
                tmp := Utils.bitrightshift(tmp, Int.abs(shiftBy));// n >>= shiftBy;

                // If the bits are bigger than max size, we'll split those.
                // +224 => 256 - 32
                if (wbits > windowSize) {
                    wbits -= maxNumber;
                    tmp += CONST._1n;
                };

                // Check if we're onto Zero point.
                // Add random point inside current window to f.
                let offset1 = offset;
                let offset2 = offset + Int.abs(wbits) - 1;
                let cond1 = window % 2 != 0;
                let cond2 = wbits < 0;
                if (wbits == 0) {
                    // The most important part for let-time getPublicKey
                    // warning ! use Int.abs()
                    if (Int.abs(offset1) < 0 or Int.abs(offset2) < 0) {
                        Debug.trap("offset < 0");
                    } else if (Int.abs(offset1) >= Array.size(precomputes) or Int.abs(offset2) >= Array.size(precomputes)) {
                        Debug.trap("offset > 0");
                    };
                    f := f.add(constTimeNegate(cond1, precomputes[Int.abs(offset1)]));
                } else {
                    p := p.add(constTimeNegate(cond2, precomputes[Int.abs(offset2)]));
                };
                window += 1;
            };
            return normalizeZ([p, f])[0];
        };

        // letant time multiplication.
        // Uses wNAF method. Windowed method may be 10% faster,
        // but takes 2x longer to generate and consumes 2x memory.
        public func multiply(scalar: Int, affinePoint: ?C_Point.Point): ExtendedPoint {
            return wNAF(Utils.normalizeScalar(scalar, CONST.CURVE.l, null), affinePoint);
        };

        // Non-letant-time multiplication. Uses double-and-add algorithm.
        // It's faster, but should only be used when you don't care about
        // an exposed private key e.g. sig verification.
        // Allows scalar bigger than curve order, but less than 2^256
        public func multiplyUnsafe(scalar: Int): ExtendedPoint {
            let n = Utils.normalizeScalar(scalar, CONST.CURVE.l, ?false);
            let G = getBase();
            let P0 = getZero();
            if (n == CONST._0n) return P0;
            if (this.equals(P0) or n == CONST._1n) return this;
            if (this.equals(G)) return wNAF(n, null);
            var p = P0;
            var d: ExtendedPoint = this;
            var tmp = n;
            while (tmp > CONST._0n) {
                if (Utils.bitand(tmp, CONST._1n) != 0) p := p.add(d);
                d := d.double();
                tmp := Utils.bitrightshift(tmp, Int.abs(CONST._1n));
            };
            return p;
        };

        public func isSmallOrder(): Bool {
            return this.multiplyUnsafe(CONST.CURVE.h).equals(getZero());
        };

        public func isTorsionFree(): Bool {
            var p = this.multiplyUnsafe(CONST.CURVE.l / CONST._2n).double();
            if (CONST.CURVE.l % CONST._2n != 0) p := p.add(this);
            return p.equals(getZero());
        };

        // Converts Extended point to default (x, y) coordinates.
        // Can accept precomputed Z^-1 - for example, from invertBatch.
        public func toAffine(invertZ: ?Int): C_Point.Point {
            let { x; y; z } = this;
            let is0 = this.equals(getZero());
            let invZ : Int = if (invertZ == null) { if (is0) CONST._8n else Utils.invert(z, null) } else Option.unwrap<Int>(invertZ); // 8 was chosen arbitrarily
            let ax = Utils.mod(x * invZ, null);
            let ay = Utils.mod(y * invZ, null);
            let zz = Utils.mod(z * invZ, null);
            if (is0) return C_Point.getZero();
            if (zz != CONST._1n) Debug.trap("invZ was invalid");
            return C_Point.Point(ax, ay);
        };

        public func fromRistrettoBytes() {
            legacyRist();
        };
        public func toRistrettoBytes() {
            legacyRist();
        };
        public func fromRistrettoHash() {
            legacyRist();
        };
    }
};

module C_RistrettoPoint {
    // let BASE = RistrettoPoint(ExtendedPoint.BASE);
    // let ZERO = RistrettoPoint(ExtendedPoint.ZERO);

    public func getZero() : RistrettoPoint {
        return RistrettoPoint(C_ExtendedPoint.getZero());
    };

    public func getBase() : RistrettoPoint {
        return RistrettoPoint(C_ExtendedPoint.getBase());
    };

    // Computes Elligator map for Ristretto
    // https://ristretto.group/formulas/elligator.html
    private func calcElligatorRistrettoMap(r0: Int): C_ExtendedPoint.ExtendedPoint {
        let { d } = CONST.CURVE;
        let r = Utils.mod(CONST.SQRT_M1 * r0 * r0, null); // 1
        let Ns = Utils.mod((r + CONST._1n) * CONST.ONE_MINUS_D_SQ, null); // 2
        var c : Int = -1; // 3
        let D = Utils.mod((c - d * r) * Utils.mod(r + d, null), null); // 4
        let { isValid = Ns_D_is_sq; x = s } = Utils.uvRatio(Ns, D); // 5
        var s_ = Utils.mod(s * r0, null); // 6
        if (Utils.edIsNegative(s_) == false) s_ := Utils.mod(-s_, null);
        let s1 = if (Ns_D_is_sq == false) s_ else s; // 7
        if (Ns_D_is_sq == false) c := r; // 8
        let Nt = Utils.mod(c * (r - CONST._1n) * CONST.D_MINUS_ONE_SQ - D, null); // 9
        let s2 = s1 * s1;
        let W0 = Utils.mod((s1 + s1) * D, null); // 10
        let W1 = Utils.mod(Nt * CONST.SQRT_AD_MINUS_ONE, null); // 11
        let W2 = Utils.mod(CONST._1n - s2, null); // 12
        let W3 = Utils.mod(CONST._1n + s2, null); // 13
        return C_ExtendedPoint.ExtendedPoint(Utils.mod(W0 * W3, null), Utils.mod(W2 * W1, null), Utils.mod(W1 * W3, null), Utils.mod(W0 * W2, null));
    };

    /**
    * Takes uniform output of 64-bit hash function like sha512 and converts it to `RistrettoPoint`.
    * The hash-to-group operation applies Elligator twice and adds the results.
    * **Note:** this is one-way map, there is no conversion from point to hash.
    * https://ristretto.group/formulas/elligator.html
    * @param hex 64-bit output of a hash function
    */
    public func hashToCurve(h: T.Hex): RistrettoPoint {
        let hex = Utils.ensureBytes(h, ?64);
        let (firstBytes, secondBytes) = Buffer.split<Nat8>(Buffer.fromArray<Nat8>(hex), 32);
        let r1 = Utils.bytes255ToNumberLE(Buffer.toArray(firstBytes));
        let R1 = calcElligatorRistrettoMap(r1);
        let r2 = Utils.bytes255ToNumberLE(Buffer.toArray(secondBytes));
        let R2 = calcElligatorRistrettoMap(r2);
        return RistrettoPoint(R1.add(R2));
    };

    /**
    * Converts ristretto-encoded string to ristretto point.
    * https://ristretto.group/formulas/decoding.html
    * @param hex Ristretto-encoded 32 bytes. Not every 32-byte string is valid ristretto encoding
    */
    public func fromHex(h: T.Hex): RistrettoPoint {
        let hex = Utils.ensureBytes(h, ?32);
        let { a; d } = CONST.CURVE;
        let emsg = "RistrettoPoint.fromHex: the hex is not valid encoding of RistrettoPoint";
        let s = Utils.bytes255ToNumberLE(hex);
        // 1. Check that s_bytes is the canonical encoding of a field element, or else abort.
        // 3. Check that s is non-negative, or else abort
        if (Utils.equalBytes(Utils.numberTo32BytesLE(s), hex) or Utils.edIsNegative(s) == false) Debug.trap(emsg);
        let s2 = Utils.mod(s * s, null);
        let u1 = Utils.mod(CONST._1n + a * s2, null); // 4 (a is -1)
        let u2 = Utils.mod(CONST._1n - a * s2, null); // 5
        let u1_2 = Utils.mod(u1 * u1, null);
        let u2_2 = Utils.mod(u2 * u2, null);
        let v = Utils.mod(a * d * u1_2 - u2_2, null); // 6
        let { isValid; x = I } = Utils.invertSqrt(Utils.mod(v * u2_2, null)); // 7
        let Dx = Utils.mod(I * u2, null); // 8
        let Dy = Utils.mod(I * Dx * v, null); // 9
        var x = Utils.mod((s + s) * Dx, null); // 10
        if (Utils.edIsNegative(x)) x := Utils.mod(-x, null); // 10
        let y = Utils.mod(u1 * Dy, null); // 11
        let t = Utils.mod(x * y, null); // 12
        if (isValid == false or Utils.edIsNegative(t) or y == CONST._0n) Debug.trap(emsg);
        return RistrettoPoint(C_ExtendedPoint.ExtendedPoint(x, y, CONST._1n, t));
    };

    public class RistrettoPoint(epParams: C_ExtendedPoint.ExtendedPoint) = this {
        // Private property to discourage combining ExtendedPoint + RistrettoPoint
        // Always use Ristretto encoding/decoding instead.
        public let ep = epParams;

        public func get() : T.RistrettoPoint {
            return {
                ep = ep;
            };
        };

        /**
        * Encodes ristretto point to [Nat8].
        * https://ristretto.group/formulas/encoding.html
        */
        private func toRawBytes(): [Nat8] {
            let res = this.ep;
            var x = res.x;
            var y = res.y;
            let z = res.z;
            let t = res.t;
            let u1 = Utils.mod(Utils.mod(z + y, null) * Utils.mod(z - y, null), null); // 1
            let u2 = Utils.mod(x * y, null); // 2
            // Square root always exists
            let u2sq = Utils.mod(u2 * u2, null);
            let { x= invsqrt } = Utils.invertSqrt(Utils.mod(u1 * u2sq, null)); // 3
            let D1 = Utils.mod(invsqrt * u1, null); // 4
            let D2 = Utils.mod(invsqrt * u2, null); // 5
            let zInv = Utils.mod(D1 * D2 * t, null); // 6
            
            var D: Int = if (Utils.edIsNegative(t * zInv)) {  // 7
                let _x = Utils.mod(y * CONST.SQRT_M1, null);
                let _y = Utils.mod(x * CONST.SQRT_M1, null);
                x := _x;
                y := _y;
                Utils.mod(D1 * CONST.INVSQRT_A_MINUS_D, null);
            } else {
                D2; // 8
            };
            if (Utils.edIsNegative(x * zInv)) y := Utils.mod(-y, null); // 9
            var s = Utils.mod((z - y) * D, null); // 10 (check footer's note, no sqrt(-a))
            if (Utils.edIsNegative(s)) s := Utils.mod(-s, null);
            return Utils.numberTo32BytesLE(s); // 11
        };

        public func toHex(): Text {
            return Utils.bytesToHex(toRawBytes());
        };

        public func toString(): Text {
            return toHex();
        };

        // Compare one point to another.
        private func equals(other: RistrettoPoint): Bool {
            // assertRstPoint(other);
            let a = this.ep;
            let b = other.ep;
            // (x1 * y2 == y1 * x2) | (y1 * y2 == x1 * x2)
            let one = Utils.mod(a.x * b.y, null) == Utils.mod(a.y * b.x, null);
            let two = Utils.mod(a.y * b.y, null) == Utils.mod(a.x * b.x, null);
            return one or two;
        };

        private func add(other: RistrettoPoint): RistrettoPoint {
            // assertRstPoint(other);
            return RistrettoPoint(this.ep.add(other.ep));
        };

        private func subtract(other: RistrettoPoint): RistrettoPoint {
            // assertRstPoint(other);
            return RistrettoPoint(this.ep.subtract(other.ep));
        };

        private func multiply(scalar: Int): RistrettoPoint {
            return RistrettoPoint(this.ep.multiply(scalar, null));
        };

        private func multiplyUnsafe(scalar: Int): RistrettoPoint {
            return RistrettoPoint(this.ep.multiplyUnsafe(scalar));
        };
    }
};

module C_Signature {

    public func fromHex(hex: T.Hex) : Signature {
        let bytes = Buffer.fromArray<Nat8>(Utils.ensureBytes(hex, ?64));
        let (firstBytes, secondBytes) = Buffer.split<Nat8>(bytes, 32);
        let r = C_Point.fromHex(#array (Buffer.toArray(firstBytes)), ?false);
        let s = Utils.bytesToNumberLE((Buffer.toArray(secondBytes)));
        return Signature(r, s);
    };

    public func tSignature2Signature(sig : T.Signature) : Signature {
        let p = C_Point.Point(sig.r.x, sig.r.y);
        p._setWindowSize(sig.r.windowSize);
        Signature(p, sig.s);
    };

    public class Signature(r1: C_Point.Point, s1: Int) = this {

        public let r = r1;
        public let s = s1;

        public func assertValidity() {
            // 0 <= s < l
            let s2 = Utils.normalizeScalar(s, CONST.CURVE.l, ?false);
        };

        assertValidity();

        public func toRawBytes() : [Nat8] {
            let u8 = Buffer.Buffer<Nat8>(64);
            u8.insertBuffer(0, Buffer.fromArray(r.toRawBytes()));
            u8.insertBuffer(32, Buffer.fromArray(Utils.numberTo32BytesLE(s)));
            return Buffer.toArray(u8);
        };

        public func toHex() : Text {
            return Utils.bytesToHex(toRawBytes());
        };
    }
};

module ed25519 {

    let BASE_POINT_U : T.Hex = #string "0900000000000000000000000000000000000000000000000000000000000000";

    /** crypto_scalarmult aka getSharedSecret */
    public func scalarMult(privateKey: T.Hex, publicKey: T.Hex): [Nat8] {
        let u = Utils.decodeUCoordinate(publicKey);
        let p = Utils.decodeScalar25519(privateKey);
        let pu = Utils.montgomeryLadder(u, p);
        // The result was not contributory
        // https://cr.yp.to/ecdh.html#validate
        if (pu == CONST._0n) Debug.trap("Invalid private or public key received");
        return Utils.encodeUCoordinate(pu);
    };

    /** crypto_scalarmult_base aka getPublicKey */
    public func scalarMultBase(privateKey: T.Hex): [Nat8] {
        return scalarMult(privateKey, BASE_POINT_U);
    };


    public func fromPrivateKey(privateKey: T.PrivKey) : C_Point.Point {
        return (getExtendedPublicKey(privateKey)).point;
    };

    // Takes 64 bytes
    func getKeyFromHash(hashed: [Nat8]) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: C_Point.Point;
                                                pointBytes: [Nat8]
                                            }
    {
        let (firstBytes, secondBytes) = Buffer.split<Nat8>(Buffer.fromArray<Nat8>(hashed), 32);
        // First 32 bytes of 64b uniformingly random input are taken,
        // clears 3 bits of it to produce a random field element.
        let head = Utils.adjustBytes25519(Buffer.toArray(firstBytes));
        // Second 32 bytes is called key prefix (5.1.6)
        let prefix = Buffer.toArray(secondBytes);
        // The actual private scalar
        let scalar = Utils.modlLE(head);
        // Point on Edwards CONST.CURVE aka public key
        let point = C_Point.getBase().multiply(scalar);
        let pointBytes = point.toRawBytes();
        return {    head=head;
                    prefix=prefix;
                    scalar=scalar;
                    point=point;
                    pointBytes=pointBytes 
                };
    };

    /** Convenience method that creates public key and other stuff. RFC8032 5.1.5 */
    public func getExtendedPublicKey(key: T.PrivKey) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: C_Point.Point;
                                                pointBytes: [Nat8]
                                            } {
                                                // warning : make array ? [Utils.checkPrivateKey(key)] 
        return getKeyFromHash(Utils.sha512([Utils.checkPrivateKey(key)]));
    };


    func getExtendedPublicKeySync(key: T.PrivKey) : {
                                                head: [Nat8];
                                                prefix: [Nat8];
                                                scalar: Int;
                                                point: C_Point.Point;
                                                pointBytes: [Nat8]
                                            } {
                                                // warning : make array ? [Utils.checkPrivateKey(key)] 
        return getKeyFromHash(Utils.sha512s([Utils.checkPrivateKey(key)]));
    };

    // Helper functions because we have async and sync methods.
    func prepareVerification(sig: T.SigType,
                            messageHex: T.Hex,
                            publicKey: T.PubKey) : {
                                                    r : C_Point.Point;
                                                    s : Int;
                                                    sb : C_ExtendedPoint.ExtendedPoint;
                                                    pub: C_Point.Point;
                                                    msg: [Nat8];
    } {
        let message = Utils.ensureBytes(messageHex, null);
        // When hex is passed, we check public key fully.
        // When Point instance is passed, we assume it has already been checked, for performance.
        // If user passes Point/Sig instance, we assume it has been already verified.
        // We don't check its equations for performance. We do check for valid bounds for s though
        // We always check for: a) s bounds. b) hex validity
        let publicKeyAsPoint = switch publicKey {
            case (#point(p)) C_Point.mapTPoint2Point(p);
            case (#hex(h)) C_Point.fromHex(h, ?false);
        };
        let sign = switch sig {
            case (#signature(s)) {
                let signature = C_Signature.tSignature2Signature(s);
                signature.assertValidity();
                signature;
            };
            case (#hex(h)) C_Signature.fromHex(h);
        };
        
        let SB = C_ExtendedPoint.getBase().multiplyUnsafe(sign.s);
        return { r=sign.r; s=sign.s; sb=SB; pub=publicKeyAsPoint; msg=message };
    };

    func finishVerification(publicKey: C_Point.Point, r: C_Point.Point, sb: C_ExtendedPoint.ExtendedPoint, hashed: [Nat8]) : Bool {
        let k = Utils.modlLE(hashed);
        let kA = C_ExtendedPoint.fromAffine(publicKey).multiplyUnsafe(k);
        let RkA = C_ExtendedPoint.fromAffine(r).add(kA);
        // [8][S]B = [8]R + [8][k]A'
        return RkA.subtract(sb).multiplyUnsafe(CONST.CURVE.h).equals(C_ExtendedPoint.getZero());
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
    public func verify(sig: T.SigType, message: T.Hex, publicKey: T.PubKey): async Bool {
        let { r; s; sb; msg; pub } = prepareVerification(sig, message, publicKey);
        // warning : add array [r.toRawBytes(), pub.toRawBytes(), msg]
        let hashed = Utils.sha512([r.toRawBytes(), pub.toRawBytes(), msg]);
        return finishVerification(pub, r, sb, hashed);
    };

    public func verifySync(sig: T.SigType, message: T.Hex, publicKey: T.PubKey): Bool {
        let { r; sb; msg; pub } = prepareVerification(sig, message, publicKey);
        // warning : add array [r.toRawBytes(), pub.toRawBytes(), msg]
        let hashed = Utils.sha512s([r.toRawBytes(), pub.toRawBytes(), msg]);
        return finishVerification(pub, r, sb, hashed);
    };

    /**
    * We're doing scalar multiplication (used in getPublicKey etc) with precomputed BASE_POINT
    * values. This slows down first getPublicKey() by milliseconds (see Speed section),
    * but allows to speed-up subsequent getPublicKey() calls up to 20x.
    * @param windowSize 2, 4, 8, 16
    */
    public func precompute(windowSize : ?Nat, p : ?C_Point.Point): C_Point.Point {
        let point = switch p {
            case null C_Point.getBase();
            case (?x) x;
        };
        let cached = if (point.equals(C_Point.getBase())) point else C_Point.Point(point.x, point.y);
        cached._setWindowSize(windowSize);
        cached.multiply(CONST._2n);
        // return cached;
    };

    /**
    * Calculates ed25519 public key. RFC8032 5.1.5
    * 1. private key is hashed with sha512, then first 32 bytes are taken from the hash
    * 2. 3 least significant bits of the first byte are cleared
    */
    public func getPublicKey(privateKey: T.PrivKey): async [Nat8] {
        return (getExtendedPublicKey(privateKey)).pointBytes;
    };

    public func getPublicKeySync(privateKey: T.PrivKey): [Nat8] {
        return getExtendedPublicKeySync(privateKey).pointBytes;
    };

    /** Signs message with privateKey. RFC8032 5.1.6 */
    public func sign(messageHex: T.Hex, privateKey: T.Hex): async [Nat8] {
        let message = Utils.ensureBytes(messageHex, null);
        let { head; prefix; scalar; point; pointBytes } = getExtendedPublicKey(#hex privateKey);
        // warning : check add array [prefix, message]
        let r = Utils.modlLE(Utils.sha512([prefix, message])); // r = hash(prefix + msg)
        let R = C_Point.getBase().multiply(r); // R = rG
        // warning : check add array [R.toRawBytes(), pointBytes, message]
        let k = Utils.modlLE(Utils.sha512([R.toRawBytes(), pointBytes, message])); // k = hash(R+P+msg)
        let s = Utils.mod(r + k * scalar, ?CONST.CURVE.l); // s = r + kp
        return C_Signature.Signature(R, s).toRawBytes();
    };

    public func signSync(messageHex: T.Hex, privateKey: T.Hex): [Nat8] {
        let message = Utils.ensureBytes(messageHex, null);
        let { prefix; scalar; pointBytes } = getExtendedPublicKeySync(#hex privateKey);
        // warning : check add array [prefix, message]
        let r = Utils.modlLE(Utils.sha512s([prefix, message])); // r = hash(prefix + msg)
        let R = C_Point.getBase().multiply(r); // R = rG
        // warning : check add array [R.toRawBytes(), pointBytes, message]
        let k = Utils.modlLE(Utils.sha512s([R.toRawBytes(), pointBytes, message])); // k = hash(R+P+msg)
        let s = Utils.mod(r + k * scalar, ?CONST.CURVE.l); // s = r + kp
        return C_Signature.Signature(R, s).toRawBytes();
    };

    /**
    * Calculates X25519 DH shared secret from ed25519 private & public keys.
    * CONST.CURVE25519 used in X25519 consumes private keys as-is, while ed25519 hashes them with sha512.
    * Which means we will need to normalize ed25519 seeds to "hashed repr".
    * @param privateKey ed25519 private key
    * @param publicKey ed25519 public key
    * @returns X25519 shared key
    */
    public func getSharedSecret(privateKey: T.PrivKey, publicKey: T.Hex): async [Nat8] {
        let { head } = getExtendedPublicKey(privateKey);
        let u = C_Point.fromHex(publicKey, null).toX25519();
        return scalarMult(#array head, #array u);
    };
}