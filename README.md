# ed25519

Motoko implementation of [ed25519](https://en.wikipedia.org/wiki/EdDSA).

This library is a porting version of  [noble-ed25519](https://github.com/paulmillr/noble-ed25519).

Dependencies :
- https://github.com/ZenVoich/fuzz // random byte (create private key)
- https://github.com/timohanke/motoko-iterext
- https://github.com/timohanke/motoko-sha2 // sha256 + sha512

## Usage

Vessel are supported:
> Setting of [dfx.json](https://github.com/nirvana369/ed25519-demo/blob/main/dfx.json) :
```json
{
    "defaults": {
      "build": {
        "packtool": "vessel sources"
      }
    },
    "version": 1
}
```
> Setting of  [package-set.dhall](https://github.com/nirvana369/ed25519-demo/blob/main/package-set.dhall) :
```
let additions = [
       { name = "ed25519"
        , version = "v1.0.0"
        , repo = "https://github.com/nirvana369/ed25519.git"
        , dependencies = [ "base" ] : List Text
        }
    ]
```

> How to use :

```
import Lib "mo:ed25519";

let privateKey = Lib.Utils.randomPrivateKey();
let message : [Nat8] = [0xab, 0xbc, 0xcd, 0xde];
let publicKey = Lib.ED25519.getPublicKey(privateKey);
let signature = Lib.ED25519.sign(message, privateKey);
let isValid = Lib.ED25519.verify(signature, message, publicKey);
```

## Demo
[(https://github.com/nirvana369/ed25519-demo)](https://github.com/nirvana369/ed25519-demo).

## License
[MIT (c) nirvana369](https://github.com/nirvana369/ed25519/blob/main/LICENSE).