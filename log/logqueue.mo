import Buffer "mo:base/Buffer";


module Queue {

    public func fromArray<T>(arr : [T]) : Queue<T> {
        return Queue<T>(?arr);
    };

    public class Queue<T>(arr : ?[T]) {

        let q = switch arr {
            case null Buffer.Buffer<T>(0);
            case (?queue) Buffer.fromArray<T>(queue);
        };

        public func dequeue() : ?T {
            q.removeLast();
        };

        public func enqueue(e : T) {
            q.add(e);
        };

        public func isEmpty() : Bool {
            not (q.size() > 0);
        };
    };
};