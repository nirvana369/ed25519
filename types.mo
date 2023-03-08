module {
    
    public type Hex = {
        #array : [Nat8];
        #string : Text;
    };

    public type PrivKey = {
        #hex : Hex;
        #bigint : Int;
        #number : Nat;
    };

    public type PubKey = { 
        #hex : Hex;
        #point : Point;
    };

    public type SigType = {
        #hex : Hex;
        #signature : Signature;
    };

    public type Signature = {
        r: Point; 
        s: Int;
    };

    public type Point = {
        x : Int;
        y : Int;
        windowSize: ?Nat;
    };

    public type ExtendedPoint = {
        x : Int;
        y : Int;
        z : Int;
        t : Int;
    };

    public type RistrettoPoint = {
        ep : ExtendedPoint;
    };

    public type Record = {
        key : Point;
        value : [ExtendedPoint];
    };

    public type Generator<T> = {
      next : () -> T;
    };

    public type Log = {
        id : Nat;
        action : Text;
        data : Text;
        time : Nat;
    };
}