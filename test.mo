import Types "types";
import FBlob "blob";
import FNat8 "nat8";
import Int "mo:base/Int";
import Time "mo:base/Time";
import Blob "mo:base/Blob";
import {ed25519} "ed25519";
import utils "utils";

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

  public func generatePrivateKey() : async Bool {
    let privateKey = utils.randomPrivateKey();
    let message : [Nat8] = [0xab, 0xbc, 0xcd, 0xde];
    let publicKey = await ed25519.getPublicKey(#hex(#array privateKey));
    let signature = await ed25519.sign(#array message, #array privateKey);
    let isValid = await ed25519.verify(#hex(#array signature), #array message, #hex(#array publicKey));
    isValid;
  };
}