import T "types";

module {
    public let _0n : Int = 0;
    public let _1n : Int = 1;
    public let _2n : Int = 2;
    public let _8n : Int = 8;
    // 2n ** 252n + 27742317777372353535851937790883648493n;
    public let CU_O : Int = 7237005577332262213973186563042994240857116359379907606001950938285454250989;
    /**
    * ed25519 is Twisted Edwards curve with equation of
    * ```
    * −x² + y² = 1 − (121665/121666) * x² * y²
    * ```
    */
    public let CURVE = {
        // Param: a
        a: Int = -1;
        // Equal to -121665/121666 over finite field.
        // Negative number is P - number, and division is invert(number, P)
        d: Int = 37095705934669439343138083508754565189542113879843219016388785533085940283555;
        // Finite field 𝔽p over which we'll do calculations; 2n ** 255n - 19n
        P: Int = 57896044618658097711785492504343953926634992332820282019728792003956564819949;
        // Subgroup order: how many points ed25519 has
        l: Int = CU_O; // in rfc8032 it's called l
        n: Int = CU_O; // backwards compatibility
        // Cofactor
        h: Int = 8;
        // Base point (x, y) aka generator point
        Gx: Int = 15112221349535400772501151409588531511454012693041857206046113283949847762202;
        Gy: Int = 46316835694926478169428394003475163141307993866256225615783033603165251855960;
    };

    public let POW_2_256 : Int = 0x10000000000000000000000000000000000000000000000000000000000000000;

    // √(-1) aka √(a) aka 2^((p-1)/4)
    public let SQRT_M1 : Int = 19681161376707505956807079304988542015446066515923890162744021073123829784752;
    // √d aka sqrt(-486664)
    public let SQRT_D : Int = 6853475219497561581579357271197624642482790079785650197046958215289687604742;
    // √(ad - 1)
    public let SQRT_AD_MINUS_ONE : Int = 25063068953384623474111414158702152701244531502492656460079210482610430750235;
    // 1 / √(a-d)
    public let INVSQRT_A_MINUS_D : Int = 54469307008909316920995813868745141605393597292927456921205312896311721017578;
    // 1-d²
    public let ONE_MINUS_D_SQ : Int = 1159843021668779879193775521855586647937357759715417654439879720876111806838;
    // (d-1)²
    public let D_MINUS_ONE_SQ : Int = 40440834346308536858101042469323190826248399146238708352240133220865137265952;

    // // Base point aka generator
    // // public_key = Point.BASE * private_key
    // public let POINT_BASE: T.Point = {x = CURVE.Gx; y = CURVE.Gy; windowSize = ?2};
    // // Identity point aka point at infinity
    // // point = point + zero_point
    // public let POINT_ZERO: T.Point = {x = _0n; y = _1n; windowSize = ?2};

    // // Base point aka generator
    // // public_key = Point.BASE * private_key
    // public let BASE: Point = Point(CONST.CURVE.Gx, CONST.CURVE.Gy);
    // // Identity point aka point at infinity
    // // point = point + zero_point
    // public let ZERO: Point = Point(CONST._0n, CONST._1n);
}