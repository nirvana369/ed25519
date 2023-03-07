import T "types";
import Time "mo:base/Time";
import Int8 "mo:base/Int8";
import Int "mo:base/Int";
import Nat "mo:base/Nat";
import Nat8 "mo:base/Nat8";
import Buffer "mo:base/Buffer";

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
        var text : Text = "";
        let sep = " | ";

        func addSep() {
            text := text # sep;
        };

        public func addNat(n : Nat) {
            text := text # Nat.toText(n);
            addSep();
        };

        public func addNat8(n : Nat8) {
            text := text # Nat8.toText(n);
            addSep();
        };

        public func addInt(n : Int) {
            text := text # Int.toText(n);
            addSep();
        };

        public func addInt8(n : Int8) {
            text := text # Int8.toText(n);
            addSep();
        };

        public func addArrayNat8(a : [Nat8]) {
            text := text # Buffer.toText(Buffer.fromArray<Nat8>(a), Nat8.toText);
        };
    };
}