import T "types";
import CONST "const";
import Point "point";
import Buffer "mo:base/Buffer";

module {

    public func fromHex(hex: T.Hex) : T.Signature {
        let bytes = Buffer.fromArray<Nat8>(ensureBytes(hex, 64));
        let (firstBytes, secondBytes) = Buffer.split<Nat>(bytes, 32);
        let r = Point.fromHex(#array firstBytes, false);
        let s = bytesToNumberLE(secondBytes);
        return {r; s};
    };

    public class Signature(r: Point, s: Int) {
        assertValidity();

        public func assertValidity() : {r : Point.Point; s : Int} {
            // 0 <= s < l
            normalizeScalar(s, CURVE.l, false);
            return {r ; s};
        };

        func toRawBytes() : [Nat8] {
            let u8 = new Uint8Array(64);
            u8.set(r.toRawBytes());
            u8.set(numberTo32BytesLE(this.s), 32);
            return u8;
        };

        func toHex() {
            return bytesToHex(toRawBytes());
        };
    }
}