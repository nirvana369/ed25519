import Types "./../types";
import FNat8 "nat8";

import Array "mo:base/Array";
import Blob "mo:base/Blob";

module {
  public class FBlob(generator : Types.Generator<Nat>) {
      let fNat8 = FNat8.FNat8(generator);
      public func random(size : Nat) : Blob {
        Blob.fromArray(Array.tabulate<Nat8>(size, func(_) = fNat8.random()));
      };
  };
}