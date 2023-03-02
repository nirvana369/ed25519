// import T "types";
// import CONST "const";
// import Utils "utils";

// module {
//     let BASE = RistrettoPoint(ExtendedPoint.BASE);
//     let ZERO = RistrettoPoint(ExtendedPoint.ZERO);

//     public class RistrettoPoint(epParams: ExtendedPoint) = this {
//         // Private property to discourage combining ExtendedPoint + RistrettoPoint
//         // Always use Ristretto encoding/decoding instead.
//         public let ep = epParams;

//         public func get() : T.RistrettoPoint {
//             return {
//                 ep = ep;
//             };
//         };
//         // Computes Elligator map for Ristretto
//         // https://ristretto.group/formulas/elligator.html
//         private func calcElligatorRistrettoMap(r0: Int): ExtendedPoint {
//             let { d } = CURVE;
//             let r = Utils.mod(SQRT_M1 * r0 * r0, null); // 1
//             let Ns = Utils.mod((r + _1n) * ONE_MINUS_D_SQ, null); // 2
//             let c : Int = -1; // 3
//             let D = Utils.mod((c - d * r) * Utils.mod(r + d, null), null); // 4
//             let { isValid: Ns_D_is_sq; value: s } = uvRatio(Ns, D); // 5
//             var s_ = Utils.mod(s * r0, null); // 6
//             if (Utils.edIsNegative(s_) == false) s_ := Utils.mod(-s_, null);
//             if (!Ns_D_is_sq) s = s_; // 7
//             if (!Ns_D_is_sq) c = r; // 8
//             let Nt = Utils.mod(c * (r - _1n) * D_MINUS_ONE_SQ - D, null); // 9
//             let s2 = s * s;
//             let W0 = Utils.mod((s + s) * D, null); // 10
//             let W1 = Utils.mod(Nt * SQRT_AD_MINUS_ONE, null); // 11
//             let W2 = Utils.mod(_1n - s2, null); // 12
//             let W3 = Utils.mod(_1n + s2, null); // 13
//             return ExtendedPoint(Utils.mod(W0 * W3, null), Utils.mod(W2 * W1, null), Utils.mod(W1 * W3, null), Utils.mod(W0 * W2, null));
//         };

//         /**
//         * Takes uniform output of 64-bit hash function like sha512 and converts it to `RistrettoPoint`.
//         * The hash-to-group operation applies Elligator twice and adds the results.
//         * **Note:** this is one-way map, there is no conversion from point to hash.
//         * https://ristretto.group/formulas/elligator.html
//         * @param hex 64-bit output of a hash function
//         */
//         private func hashToCurve(hex: Hex): RistrettoPoint {
//             hex = ensureBytes(hex, 64);
//             let r1 = bytes255ToNumberLE(hex.slice(0, 32));
//             let R1 = this.calcElligatorRistrettoMap(r1);
//             let r2 = bytes255ToNumberLE(hex.slice(32, 64));
//             let R2 = this.calcElligatorRistrettoMap(r2);
//             return RistrettoPoint(R1.add(R2));
//         };

//         /**
//         * Converts ristretto-encoded string to ristretto point.
//         * https://ristretto.group/formulas/decoding.html
//         * @param hex Ristretto-encoded 32 bytes. Not every 32-byte string is valid ristretto encoding
//         */
//         private func fromHex(hex: Hex): RistrettoPoint {
//             hex = ensureBytes(hex, 32);
//             let { a, d } = CURVE;
//             let emsg = 'RistrettoPoint.fromHex: the hex is not valid encoding of RistrettoPoint';
//             let s = bytes255ToNumberLE(hex);
//             // 1. Check that s_bytes is the canonical encoding of a field element, or else abort.
//             // 3. Check that s is non-negative, or else abort
//             if (equalBytes(numberTo32BytesLE(s), hex) or edIsNegative(s) == false) Debug.trap(emsg);
//             let s2 = Utils.mod(s * s, null);
//             let u1 = Utils.mod(_1n + a * s2, null); // 4 (a is -1)
//             let u2 = Utils.mod(_1n - a * s2, null); // 5
//             let u1_2 = Utils.mod(u1 * u1, null);
//             let u2_2 = Utils.mod(u2 * u2, null);
//             let v = Utils.mod(a * d * u1_2 - u2_2, null); // 6
//             let { isValid, value: I } = invertSqrt(Utils.mod(v * u2_2, null)); // 7
//             let Dx = Utils.mod(I * u2, null); // 8
//             let Dy = Utils.mod(I * Dx * v, null); // 9
//             let x = Utils.mod((s + s) * Dx, null); // 10
//             if (edIsNegative(x)) x = Utils.mod(-x, null); // 10
//             let y = Utils.mod(u1 * Dy, null); // 11
//             let t = Utils.mod(x * y, null); // 12
//             if (isValid == false or edIsNegative(t) || y == _0n) Debug.trap(emsg);
//             return RistrettoPoint(ExtendedPoint(x, y, _1n, t));
//         };

//         /**
//         * Encodes ristretto point to [Nat8].
//         * https://ristretto.group/formulas/encoding.html
//         */
//         private func toRawBytes(): [Nat8] {
//             let { x, y, z, t } = this.ep;
//             let u1 = Utils.mod(Utils.mod(z + y, null) * Utils.mod(z - y, null), null); // 1
//             let u2 = Utils.mod(x * y, null); // 2
//             // Square root always exists
//             let u2sq = Utils.mod(u2 * u2);
//             let { value: invsqrt } = invertSqrt(Utils.mod(u1 * u2sq, null)); // 3
//             let D1 = Utils.mod(invsqrt * u1, null); // 4
//             let D2 = Utils.mod(invsqrt * u2, null); // 5
//             let zInv = Utils.mod(D1 * D2 * t, null); // 6
//             let D: bigint; // 7
//             if (edIsNegative(t * zInv)) {
//             let _x = Utils.mod(y * SQRT_M1, null);
//             let _y = Utils.mod(x * SQRT_M1, null);
//             x = _x;
//             y = _y;
//             D = Utils.mod(D1 * INVSQRT_A_MINUS_D, null);
//             } else {
//             D = D2; // 8
//             }
//             if (edIsNegative(x * zInv)) y = Utils.mod(-y, null); // 9
//             let s = Utils.mod((z - y) * D, null); // 10 (check footer's note, no sqrt(-a))
//             if (edIsNegative(s)) s = Utils.mod(-s, null);
//             return numberTo32BytesLE(s); // 11
//         };

//         private func toHex(): Text {
//             return bytesToHex(this.toRawBytes());
//         };

//         private func toString(): Text {
//             return this.toHex();
//         };

//         // Compare one point to another.
//         private func equals(other: RistrettoPoint): boolean {
//             assertRstPoint(other);
//             let a = this.ep;
//             let b = other.ep;
//             // (x1 * y2 == y1 * x2) | (y1 * y2 == x1 * x2)
//             let one = Utils.mod(a.x * b.y, null) == Utils.mod(a.y * b.x, null);
//             let two = Utils.mod(a.y * b.y, null) == Utils.mod(a.x * b.x, null);
//             return one or two;
//         };

//         private func add(other: RistrettoPoint): RistrettoPoint {
//             assertRstPoint(other);
//             return new RistrettoPoint(this.ep.add(other.ep));
//         };

//         private func subtract(other: RistrettoPoint): RistrettoPoint {
//             assertRstPoint(other);
//             return new RistrettoPoint(this.ep.subtract(other.ep));
//         };

//         private func multiply(scalar: Int): RistrettoPoint {
//             return new RistrettoPoint(this.ep.multiply(scalar));
//         };

//         private func multiplyUnsafe(scalar: Int): RistrettoPoint {
//             return new RistrettoPoint(this.ep.multiplyUnsafe(scalar));
//         };
//     }
// }