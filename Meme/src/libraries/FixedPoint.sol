// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// Simplified FixedPoint library compatible with Solidity 0.8.x
library FixedPoint {
    // range: [0, 2**112 - 1]
    // resolution: 1 / 2**112
    struct uq112x112 {
        uint224 _x;
    }

    // range: [0, 2**144 - 1]
    // resolution: 1 / 2**112
    struct uq144x112 {
        uint256 _x;
    }

    uint8 private constant RESOLUTION = 112;
    uint256 private constant Q112 = 2**112;
    uint256 private constant Q224 = 2**224;

    // encode a uint112 as a UQ112x112
    function encode(uint112 x) internal pure returns (uq112x112 memory) {
        return uq112x112(uint224(x) << RESOLUTION);
    }

    // encodes a uint144 as a UQ144x112
    function encode144(uint144 x) internal pure returns (uq144x112 memory) {
        return uq144x112(uint256(x) << RESOLUTION);
    }

    // decode a UQ112x112 into a uint112 by truncating after the radix point
    function decode(uq112x112 memory self) internal pure returns (uint112) {
        return uint112(self._x >> RESOLUTION);
    }

    // decode a UQ144x112 into a uint144 by truncating after the radix point
    function decode144(uq144x112 memory self) internal pure returns (uint144) {
        return uint144(self._x >> RESOLUTION);
    }

    // multiply a UQ112x112 by a uint, returning a UQ144x112
    function mul(uq112x112 memory self, uint256 y) internal pure returns (uq144x112 memory) {
        uint256 z = 0;
        require(y == 0 || (z = self._x * y) / y == self._x, 'FixedPoint: MUL_OVERFLOW');
        return uq144x112(z);
    }

    // multiply a UQ112x112 by an int and decode, returning an int
    function muli(uq112x112 memory self, int256 y) internal pure returns (int256) {
        uint256 z = mul(self, uint256(y < 0 ? -y : y))._x;
        require(z < 2**255, 'FixedPoint: MULI_OVERFLOW');
        return y < 0 ? -int256(z >> RESOLUTION) : int256(z >> RESOLUTION);
    }

    // multiply a UQ112x112 by a UQ112x112, returning a UQ112x112
    function muluq(uq112x112 memory self, uq112x112 memory other) internal pure returns (uq112x112 memory) {
        if (self._x == 0 || other._x == 0) {
            return uq112x112(0);
        }
        uint112 upper = uint112(self._x >> RESOLUTION); // * 2^0
        uint112 lower = uint112(self._x & (Q112 - 1)); // * 2^-112
        uint112 uppers = uint112(other._x >> RESOLUTION); // * 2^0
        uint112 lowers = uint112(other._x & (Q112 - 1)); // * 2^-112

        // partial products
        uint224 upper_upper = uint224(upper) * uppers; // * 2^0
        uint224 lower_upper = uint224(lower) * uppers; // * 2^-112
        uint224 upper_lower = uint224(upper) * lowers; // * 2^-112
        uint224 lower_lower = uint224(lower) * lowers; // * 2^-224

        // so the bit shift does not overflow
        require(upper_upper <= type(uint112).max, 'FixedPoint: MULUQ_OVERFLOW_UPPER');

        // this cannot exceed 256 bits, all values are 224 bits
        uint256 sum = uint256(upper_upper << RESOLUTION) + lower_upper + upper_lower + (lower_lower >> RESOLUTION);

        // so the cast does not overflow
        require(sum <= type(uint224).max, 'FixedPoint: MULUQ_OVERFLOW_SUM');

        return uq112x112(uint224(sum));
    }

    // divide a UQ112x112 by a UQ112x112, returning a UQ112x112
    function divuq(uq112x112 memory self, uq112x112 memory other) internal pure returns (uq112x112 memory) {
        require(other._x > 0, 'FixedPoint: DIV_BY_ZERO');
        uint256 value = (uint256(self._x) << RESOLUTION) / other._x;
        require(value <= type(uint224).max, 'FixedPoint: DIVUQ_OVERFLOW');
        return uq112x112(uint224(value));
    }

    // returns a UQ112x112 which represents the ratio of the numerator to the denominator
    function fraction(uint256 numerator, uint256 denominator) internal pure returns (uq112x112 memory) {
        require(denominator > 0, 'FixedPoint: DIV_BY_ZERO');
        if (numerator == 0) return FixedPoint.uq112x112(0);

        if (numerator <= type(uint144).max) {
            uint256 result = (numerator << RESOLUTION) / denominator;
            require(result <= type(uint224).max, 'FixedPoint: FRACTION_OVERFLOW');
            return uq112x112(uint224(result));
        } else {
            uint256 result = (numerator / denominator) << RESOLUTION;
            require(result <= type(uint224).max, 'FixedPoint: FRACTION_OVERFLOW');
            return uq112x112(uint224(result));
        }
    }

    // take the reciprocal of a UQ112x112, returning a UQ112x112
    function reciprocal(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        require(self._x != 0, 'FixedPoint: RECIPROCAL_ZERO');
        uint256 value = (Q224) / self._x;
        require(value <= type(uint224).max, 'FixedPoint: RECIPROCAL_OVERFLOW');
        return uq112x112(uint224(value));
    }

    // square root of a UQ112x112, returning a UQ112x112
    function sqrt(uq112x112 memory self) internal pure returns (uq112x112 memory) {
        if (self._x <= type(uint144).max) {
            return uq112x112(uint224(sqrt(uint256(self._x) << 112)));
        }

        uint256 value;
        uint256 x = self._x;
        uint256 z = (x + 1) / 2;
        value = x;
        while (z < value) {
            value = z;
            z = (x / z + z) / 2;
        }
        return uq112x112(uint224(value));
    }

    function sqrt(uint256 x) private pure returns (uint256) {
        if (x == 0) return 0;
        uint256 z = (x + 1) / 2;
        uint256 y = x;
        while (z < y) {
            y = z;
            z = (x / z + z) / 2;
        }
        return y;
    }
}