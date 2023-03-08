import Queue "logqueue";
import T "./../types";

import HashMap "mo:base/HashMap";
import Nat "mo:base/Nat";
import Hash "mo:base/Hash";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";


actor {

    let queue : Queue.Queue<T.Log> = Queue.fromArray<T.Log>([]);
    let logData : HashMap.HashMap<Nat, [T.Log]> = HashMap.HashMap<Nat, [T.Log]>(0, Nat.equal, Hash.hash);

    public shared func log(data : T.Log) {
        queue.enqueue(data);
    };

    public shared func sync() {
        while (queue.isEmpty() == false) {
            let item = queue.dequeue();
            switch item {
                case (?log) {
                    switch (logData.get(log.id)) {
                        case null logData.put(log.id, [log]);
                        case (?arr) {
                            let buf = Buffer.fromArray<T.Log>(arr);
                            buf.add(log);
                            logData.put(log.id, Buffer.toArray(buf));
                        }
                    };
                };
                case null ();
            };
        };
    };

    public func get(id : Nat) : async [T.Log] {
        switch (logData.get(id)) {
            case (?arr) arr;
            case null [];
        };
    };

    public func clear(id : Nat) : async () {
        logData.delete(id);
    };
}