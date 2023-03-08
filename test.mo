import Types "types";
import FBlob "blob";
import FNat8 "nat8";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import {ed25519; C_Point; C_ExtendedPoint} "ed25519";
import {log; LogBuilder} "logger";
import utils "utils";
import Array "mo:base/Array";
import CONST "const";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";




actor {
    func createGenerator(): Types.Generator<Nat> {
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

    public func natGen() : async Nat {
        let t : Types.Generator<Nat> = createGenerator();
        t.next();
    };

    public func nat8Gen() : async Nat8 {
        let t : Types.Generator<Nat> = createGenerator();
        let nat8 = FNat8.FNat8(t);
        nat8.random();
    };

    public func blobGen() : async [Nat8] {
      let gen : Types.Generator<Nat> = createGenerator();
      let blob = FBlob.FBlob(gen);
      let b = blob.random(64);
      Blob.toArray(b);
    };

    public func generatePrivateKey() : async [Nat8] {
      let privateKey = utils.randomPrivateKey();
      privateKey;
    };

    public func generatePubKey() : async [Nat8] {
      let privateKey = utils.randomPrivateKey();
      let message : [Nat8] = [0xab, 0xbc, 0xcd, 0xde];
      let publicKey = await ed25519.getPublicKey(#hex(#array privateKey));
      publicKey;
    };

    public func sign(privateKey : [Nat8]) : async [Nat8] {
      // let privateKey = utils.randomPrivateKey();
      // let privateKey : [Nat8] = [0xde, 0xad, 0xbe, 0xef];
      let message : [Nat8] = [0xab, 0xbc, 0xcd, 0xde];
      let publicKey = await ed25519.getPublicKey(#hex(#array privateKey));
      let signature = await ed25519.sign(#array message, #array privateKey);
      signature;
    };

    public func valid() : async Bool {
      let privateKey = utils.randomPrivateKey();
      let message : [Nat8] = [0xab, 0xbc, 0xcd, 0xde];
      let publicKey = await ed25519.getPublicKey(#hex(#array privateKey));
      let signature = await ed25519.sign(#array message, #array privateKey);
      let isValid = await ed25519.verify(#hex(#array signature), #array message, #hex(#array publicKey));
      isValid;
    };

    public func getExtendPubkey() : async {head: [Nat8];
                                                  prefix: [Nat8];
                                                  scalar: Int;
                                                  point: Types.Point;
                                                  pointBytes: [Nat8]} {
                                                    let privateKey = utils.randomPrivateKey();
      let { head; prefix; scalar; point; pointBytes } = ed25519.getExtendedPublicKey(#hex(#array privateKey));
      { head; prefix; scalar; point=point.get(); pointBytes };
    };

    public func preprocess() : async () {
        let scalar = 2213842100250961291737180463002636389159747100531892855582993179906367682511;

        let extPoint = C_ExtendedPoint.fromAffine(C_Point.getBase());
        let extPointMultiply = extPoint.multiply(scalar, ?C_Point.getBase());
        let point = extPointMultiply.toAffine(null);
        let builder = LogBuilder();
        builder.addExPoint(extPoint.get());
        builder.addExPoint(extPointMultiply.get());
        builder.addPoint(point.get());
        await log(2, "multiply", builder.toString(" | "));
        
        let x = wNAF(extPoint, scalar, ?C_Point.getBase());
        await log(3, "wNAF", x);
    };

    func toAffineBatch(points: [C_ExtendedPoint.ExtendedPoint]): [C_Point.Point] {
            let toInv = utils.invertBatch(Array.map<C_ExtendedPoint.ExtendedPoint, Int>(points, func p = p.z), CONST.CURVE.P);
            var i = 0;
            let ret = Array.map<C_ExtendedPoint.ExtendedPoint, C_Point.Point>(points, func p : C_Point.Point {
                let tmp = p.toAffine(?toInv[i]);
                i += 1;
                tmp;
            });
            // return points.map((p, i) => p.toAffine(toInv[i]));
            return ret;
        };

    func normalizeZ(points: [C_ExtendedPoint.ExtendedPoint]): [C_ExtendedPoint.ExtendedPoint] {
        return Array.map<C_Point.Point, C_ExtendedPoint.ExtendedPoint>(toAffineBatch(points), func p = C_ExtendedPoint.fromAffine(p));
        // return toAffineBatch(points).map(this.fromAffine);
    };

    private func precomputeWindow(ep: C_ExtendedPoint.ExtendedPoint, W: Int): [C_ExtendedPoint.ExtendedPoint] {
            let windows = 1 + 256 / W;
            let points = Buffer.Buffer<C_ExtendedPoint.ExtendedPoint>(0);
            var p: C_ExtendedPoint.ExtendedPoint = ep;
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
            return Buffer.toArray<C_ExtendedPoint.ExtendedPoint>(points);
        };

    func wNAF(ep: C_ExtendedPoint.ExtendedPoint, n: Int, affPoint: ?C_Point.Point): Text {
            // let affinePoint : Point.Point = if ((affPoint == null) and this.equals(ExtendedPoint.BASE)) Point.BASE else Option.unwrap(affPoint);
            let builder = LogBuilder();
            let affinePoint : C_Point.Point = switch affPoint {
                case (?p) p;
                case null C_Point.getBase();
            };
            // let W = if (affinePoint != null) affinePoint.getWindowSize() else 1;
            let W = switch (affinePoint.getWindowSize()) {
                case null 1;
                case (?s) s;
            };
            if (256 % W != 0) {
                Debug.trap("Point#wNAF: Invalid precomputation window, must be power of 2");
            };
            

            // warning ! need pre calculate to faster
            var precomputes = normalizeZ(precomputeWindow(ep, W));

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

            var p = C_ExtendedPoint.getZero();
            var f = C_ExtendedPoint.getBase();

            let windows = 1 + 256 / W;
            let windowSize = 2 ** (W - 1);
            let mask : Int = 2 ** W - 1; // Create mask with W ones: 0b1111 for W=4 etc.
            let maxNumber = 2 ** W;
            let shiftBy = W;

            builder.addNat(windows);
            builder.addNat(windowSize);
            builder.addInt(mask);
            builder.addNat(maxNumber);
            builder.addNat(shiftBy);

            builder.addNat(precomputes.size());

            var window = 0;
            var tmp = n;
            while (window < windows) {
                let offset : Int = window * windowSize;
                // Extract W bits.
                var wbits = utils.bitand(tmp, mask); //Number(n & mask);

                // Shift number by W bits.
                tmp := utils.bitrightshift(tmp, Int.abs(shiftBy));// n >>= shiftBy;

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
                    f := f.add(C_ExtendedPoint.constTimeNegate(cond1, precomputes[Int.abs(offset1)]));
                } else {
                    p := p.add(C_ExtendedPoint.constTimeNegate(cond2, precomputes[Int.abs(offset2)]));
                };
                window += 1;
                builder.addInt(offset);
                builder.addInt(wbits);
                builder.addInt(tmp);
                builder.addInt(offset1);
                builder.addInt(offset2);
                builder.addBool(cond1);
                builder.addBool(cond2);
                builder.addExPoint(f);
                builder.addExPoint(p);
                builder.addSep();
            };
            builder.addText("------------------RESULT------------------------");
            let x = normalizeZ([p, f]);
            for (y in x.vals()) {
                builder.addExPoint(y);
            };
            return builder.toString(" | ");
        };
}