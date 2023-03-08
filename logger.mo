import T "types";
import Time "mo:base/Time";
import Int8 "mo:base/Int8";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";


module {
    public type Logger = actor {
        log : shared (T.Log) -> async ();
    };

    public func log(id : Nat, action : Text, data : Text) : async () {
        let logger : Logger = actor("ryjl3-tyaaa-aaaaa-aaaba-cai");
        let logdata = {
            id = id;
            action = action;
            data = data;
            time = Int.abs(Time.now());
        };
        ignore logger.log(logdata);
    };

    public class LogBuilder() {
        let s = Buffer.Buffer<Text>(0);

        public func addText(t : Text) {
            s.add(t);
        };

        public func addNat(n : Nat) {
            s.add(Nat.toText(n));
        };

        public func addNat8(n : Nat8) {
            s.add(Nat8.toText(n));
        };

        public func addInt(n : Int) {
            s.add(Int.toText(n));
        };

        public func addInt8(n : Int8) {
            s.add(Int8.toText(n));
        };

        public func addSep() {
            s.add("***");
        };

        public func addBool(n : Bool) {
            s.add(if (n) "true" else "false");
        };

        public func addArrayNat8(a : [Nat8]) {
            s.add(Buffer.toText(Buffer.fromArray<Nat8>(a), Nat8.toText));
        };

        public func addPoint(p : T.Point) {
            let windowSize = switch (p.windowSize) {
                case null "null";
                case (?wds) Nat.toText(wds);
            };
            s.add("{x=" # Int.toText(p.x) # ";y=" # Int.toText(p.y) # ";windowSize=" # windowSize);
        };

        public func addExPoint(p : T.ExtendedPoint) {
            s.add("{x=" # Int.toText(p.x) # ";y=" # Int.toText(p.y) # ";t=" # Int.toText(p.t) # ";z=" # Int.toText(p.z));
        };


        public func toString(sep : Text) : Text {
            Text.join(sep, s.vals());
        };

        public func clear() {
            s.clear();
        };
    };
}