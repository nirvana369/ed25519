import HashMap "mo:base/HashMap";
import Hash "mo:base/Hash";
import T "types";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Int "mo:base/Int";
 
module {

    // CRUD functions
    // create + update
    public func put(array : [T.Record], k : T.Point, v : [T.ExtendedPoint]) : [T.Record] {
        let buff = Buffer.fromArray<T.Record>(array);
        let value = {
            key = k;
            value = v;
        };
        buff.filterEntries(func(_, r) = r.key.x != k.x or r.key.y != k.y); 
        buff.add(value);
        Buffer.toArray(buff);
    };

    func equal(a : T.Record, b : T.Record) : Bool {
        return a.key.x == b.key.x and a.key.y == b.key.y;
    };

    public func get(array : [T.Record], k : T.Point) : ?T.Record {
        let buff = Buffer.fromArray<T.Record>(array);
        let value = {
            key = k;
            value = [];
        };
        let index = Buffer.indexOf<T.Record>(value, buff, equal);
        switch index {
            case null null;
            case (?i) buff.getOpt(i); 
        };
    };

    // private func update(k : T.Point, value : [T.ExtendedPoint]) : () {
    //     cache.put(k, value);
    // };

    public func delete(array : [T.Record], k : T.Point) : [T.Record] {
        let buff = Buffer.fromArray<T.Record>(array);
        buff.filterEntries(func(_, r) = r.key.x != k.x or r.key.y != k.y); 
        Buffer.toArray(buff);
    };

    // public func exist(k : T.Point) : Bool {
    //     return false;
    // };

    // public func _getKey(k : T.Point) : Text {
    //     return 
    // };
}