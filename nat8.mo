import Types "types";

import Nat8 "mo:base/Nat8";

module {
  public class FNat8(generator : Types.Generator<Nat>) {
      public func min(): Nat8 {
        0;
      };

      public func max(): Nat8 {
        255;
      };
      public func random() : Nat8 {
        let x = generator.next();
        Nat8.fromIntWrap(x);
      };

      public func randomRange(min: Nat8, max: Nat8): Nat8 {
        let rand = generator.next();
        Nat8.fromIntWrap(range(rand, Nat8.toNat(min), Nat8.toNat(max)));
      };

      func range(value: Int, min: Int, max: Int): Int {
        assert(min < max);
        value % (max - min + 1) + min;
      };
  };
}