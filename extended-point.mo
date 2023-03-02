// import T "types";
// import Const "const";
// import Utils "utils";

// module {
    

//     public class ExtendedPoint(
//                                 xP : Int,
//                                 yP : Int,
//                                 zP : Int,
//                                 tP : Int) {

//         public let BASE : ExtendedPoint = ExtendedPoint(CURVE.Gx, CURVE.Gy, _1n, Utils.mod(CURVE.Gx * CURVE.Gy, null));
//         public let ZERO : ExtendedPoint = ExtendedPoint(_0n, _1n, _1n, _0n);

//         public let x = xP;
//         public let y = yP;
//         public let z = zP;
//         public let t = tP;

//         public func get() : T.ExtendedPoint {
//             return {
//                 x = x;
//                 y = y;
//                 z = z;
//                 t = t;
//             };
//         };
        
//         public func fromAffine(p: T.Point): ExtendedPoint {
//             // if (!(p instanceof Point)) {
//             // throw new TypeError('ExtendedPoint#fromAffine: expected Point');
//             // }
//             if (p.x == 0 and p.y == 1) return ZERO;
//             return ExtendedPoint(p.x, p.y, _1n, Utils.mod(p.x * p.y, null));
//         };
//         // Takes a bunch of Jacobian Points but executes only one
//         // invert on all of them. invert is very slow operation,
//         // so this improves performance massively.
//         func toAffineBatch(points: [ExtendedPoint]): [Point] {
//             let toInv = Utils.invertBatch(Array.map<ExtendedPoint, Int>(points, func p = p.z), CURVE.P);
//             var i = 0;
//             let ret = Array.map<ExtendedPoint, Point>(points, func p : Point {
//                 let tmp = p.toAffine(toInv[i]);
//                 i += 1;
//                 tmp;
//             });
//             // return points.map((p, i) => p.toAffine(toInv[i]));
//             return ret;
//         };

//         public func normalizeZ(points: [ExtendedPoint]): [ExtendedPoint] {
//             return toAffineBatch(points).map(this.fromAffine);
//         };

//         // Compare one point to another.
//         public func equals(other: ExtendedPoint): boolean {
//             assertExtPoint(other);
//             let { x: X1; y: Y1; z: Z1 } = this;
//             let { x: X2; y: Y2; z: Z2 } = other;
//             let X1Z2 = Utils.mod(X1 * Z2, null);
//             let X2Z1 = Utils.mod(X2 * Z1, null);
//             let Y1Z2 = Utils.mod(Y1 * Z2, null);
//             let Y2Z1 = Utils.mod(Y2 * Z1, null);
//             return X1Z2 == X2Z1 and Y1Z2 == Y2Z1;
//         };

//         // Inverses point to one corresponding to (x, -y) in Affine coordinates.
//         public func negate(): ExtendedPoint {
//             return new ExtendedPoint(Utils.mod(-this.x), this.y, this.z, Utils.mod(-this.t));
//         };

//         // Fast algo for doubling Extended Point
//         // https://hyperelliptic.org/EFD/g1p/auto-twisted-extended.html#doubling-dbl-2008-hwcd
//         // Cost: 4M + 4S + 1*a + 6add + 1*2.
//         public func double(): ExtendedPoint {
//             let { x: X1; y: Y1; z: Z1 } = this;
//             let { a } = CURVE;
//             let A = Utils.mod(X1 * X1, null);
//             let B = Utils.mod(Y1 * Y1, null);
//             let C = Utils.mod(_2n * Utils.mod(Z1 * Z1, null), null);
//             let D = Utils.mod(a * A, null);
//             let x1y1 = X1 + Y1;
//             let E = Utils.mod(Utils.mod(x1y1 * x1y1, null) - A - B, null);
//             let G = D + B;
//             let F = G - C;
//             let H = D - B;
//             let X3 = Utils.mod(E * F, null);
//             let Y3 = Utils.mod(G * H, null);
//             let T3 = Utils.mod(E * H, null);
//             let Z3 = Utils.mod(F * G, null);
//             return new ExtendedPoint(X3, Y3, Z3, T3);
//         };

//         // Fast algo for adding 2 Extended Points when curve's a=-1.
//         // http://hyperelliptic.org/EFD/g1p/auto-twisted-extended-1.html#addition-add-2008-hwcd-4
//         // Cost: 8M + 8add + 2*2.
//         // Note: It does not check whether the `other` point is valid.
//         public func add(other: ExtendedPoint) {
//             assertExtPoint(other);
//             let { x: X1; y: Y1; z: Z1; t: T1 } = this;
//             let { x: X2; y: Y2; z: Z2; t: T2 } = other;
//             let A = Utils.mod((Y1 - X1) * (Y2 + X2), null);
//             let B = Utils.mod((Y1 + X1) * (Y2 - X2), null);
//             let F = Utils.mod(B - A, null);
//             if (F == _0n) return this.double(); // Same point.
//             let C = Utils.mod(Z1 * _2n * T2, null);
//             let D = Utils.mod(T1 * _2n * Z2, null);
//             let E = D + C;
//             let G = B + A;
//             let H = D - C;
//             let X3 = Utils.mod(E * F, null);
//             let Y3 = Utils.mod(G * H, null);
//             let T3 = Utils.mod(E * H, null);
//             let Z3 = Utils.mod(F * G, null);
//             return new ExtendedPoint(X3, Y3, Z3, T3);
//         };

//         public func subtract(other: ExtendedPoint): ExtendedPoint {
//             return this.add(other.negate());
//         };

//         private func precomputeWindow(W: Int): [ExtendedPoint] {
//             let windows = 1 + 256 / W;
//             let points: [ExtendedPoint] = Buffer.Buffer<ExtendedPoint>(0);
//             let p: ExtendedPoint = this;
//             var base = p;
//             var window = 0;
//             while (window < windows) {
//                 base := p;
//                 points.add(base);
//                 var i = 1;
//                 while (i < 2 ** (W - 1)) {
//                     base := base.add(p);
//                     points.add(base);
//                     i += 1;
//                 };
//                 p := base.double();
//                 window += 1;
//             };
//             return Buffer.toArray<ExtendedPoint>(points);
//         };

//         private func wNAF(n: Int, affPoint: ?Point): ExtendedPoint {
//             let affinePoint = if (affinePoint == null and this.equals(ExtendedPoint.BASE)) Point.BASE else Option.unwrap(affPoint);
//             let W = if (affinePoint != null) affinePoint.getWindowSize() else 1;
//             if (256 % W != 0) {
//                 Debug.trap("Point#wNAF: Invalid precomputation window, must be power of 2");
//             };

//             var precomputes = affinePoint and pointPrecomputes.get(affinePoint);
//             if (precomputes == false) {
//                 precomputes := this.precomputeWindow(W);
//                 if (affinePoint and W != 1) {
//                     precomputes := ExtendedPoint.normalizeZ(precomputes);
//                     pointPrecomputes.set(affinePoint, precomputes);
//                 };
//             };

//             var p = ExtendedPoint.ZERO;
//             var f = ExtendedPoint.BASE;

//             let windows = 1 + 256 / W;
//             let windowSize = 2 ** (W - 1);
//             let mask = BigInt(2 ** W - 1); // Create mask with W ones: 0b1111 for W=4 etc.
//             let maxNumber = 2 ** W;
//             let shiftBy = BigInt(W);

//             var window = 0;
//             while (window < windows) {
//                 let offset = window * windowSize;
//                 // Extract W bits.
//                 let wbits = Number(n & mask);

//                 // Shift number by W bits.
//                 n >>= shiftBy;

//                 // If the bits are bigger than max size, we'll split those.
//                 // +224 => 256 - 32
//                 if (wbits > windowSize) {
//                     wbits -= maxNumber;
//                     n += _1n;
//                 };

//                 // Check if we're onto Zero point.
//                 // Add random point inside current window to f.
//                 let offset1 = offset;
//                 let offset2 = offset + Math.abs(wbits) - 1;
//                 let cond1 = window % 2 != 0;
//                 let cond2 = wbits < 0;
//                 if (wbits == 0) {
//                     // The most important part for let-time getPublicKey
//                     f := f.add(letTimeNegate(cond1, precomputes[offset1]));
//                 } else {
//                     p := p.add(letTimeNegate(cond2, precomputes[offset2]));
//                 };
//                 window += 1;
//             };
//             return ExtendedPoint.normalizeZ([p, f])[0];
//         };

//         // letant time multiplication.
//         // Uses wNAF method. Windowed method may be 10% faster,
//         // but takes 2x longer to generate and consumes 2x memory.
//         public func multiply(scalar: Int, affinePoint: ?Point): ExtendedPoint {
//             return wNAF(normalizeScalar(scalar, CURVE.l), affinePoint);
//         };

//         // Non-letant-time multiplication. Uses double-and-add algorithm.
//         // It's faster, but should only be used when you don't care about
//         // an exposed private key e.g. sig verification.
//         // Allows scalar bigger than curve order, but less than 2^256
//         public func multiplyUnsafe(scalar: Int): ExtendedPoint {
//             let n = normalizeScalar(scalar, CURVE.l, false);
//             let G = ExtendedPoint.BASE;
//             let P0 = ExtendedPoint.ZERO;
//             if (n == _0n) return P0;
//             if (this.equals(P0) or n == _1n) return this;
//             if (this.equals(G)) return this.wNAF(n);
//             var p = P0;
//             var d: ExtendedPoint = this;
//             while (n > _0n) {
//             if (n & _1n) p := p.add(d);
//                 d := d.double();
//                 n >>= _1n;
//             };
//             return p;
//         };

//         public func isSmallOrder(): boolean {
//             return this.multiplyUnsafe(CURVE.h).equals(ExtendedPoint.ZERO);
//         };

//         public func isTorsionFree(): boolean {
//             var p = this.multiplyUnsafe(CURVE.l / _2n).double();
//             if (CURVE.l % _2n) p := p.add(this);
//             return p.equals(ExtendedPoint.ZERO);
//         };

//         // Converts Extended point to default (x, y) coordinates.
//         // Can accept precomputed Z^-1 - for example, from invertBatch.
//         public func toAffine(invZ: ?Int): Point {
//             let { x; y; z } = this;
//             let is0 = this.equals(ExtendedPoint.ZERO);
//             let invZ = if (invZ == null) { if (is0) _8n else invert(z) }; // 8 was chosen arbitrarily
//             let ax = Utils.mod(x * invZ, null);
//             let ay = Utils.mod(y * invZ, null);
//             let zz = Utils.mod(z * invZ, null);
//             if (is0) return Point.ZERO;
//             if (zz != _1n) Debug.trap("invZ was invalid");
//             return Point(ax, ay);
//         };

//         public func fromRistrettoBytes() {
//             legacyRist();
//         };
//         public func toRistrettoBytes() {
//             legacyRist();
//         };
//         public func fromRistrettoHash() {
//             legacyRist();
//         };
//     }
// }