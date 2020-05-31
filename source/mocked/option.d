module mocked.option;

import std.stdio;
import std.format;
import std.meta;
import std.traits;

/**
 * Takes template parameter $(D_PARAM F), which is used to compare two objects
 * of some type.
 *
 * $(D_PARAM F) should be a callable accepting exactly 2 arguments of the same
 * type a returning a $(D_KEYWORD bool).
 *
 * Params:
 *     F = The actual comparator.
 */
struct Comparator(F...)
if (F.length == 1
    && isCallable!(F[0])
    && is(ReturnType!F == bool)
    && allSameType!(Parameters!F)
    && Parameters!F.length == 2)
{
    private alias T = Parameters!F[0];
    private alias compare = F[0];
}

/**
 * Compile-time mocker options.
 *
 * Params:
 *     Args = Option list.
 */
struct Options(Args...)
{
    /**
     * Fallback method that tests whether $(D_PARAM a) is equal to $(D_PARAM b).
     * It simply does $(D_KEYWORD ==) comparison.
     *
     * Params:
     *     a = Left-hand side operand. 
     *     b = Right-hand side operand.
     *
     * Returns: $(D_KEYWORD true) if `a == b`, $(D_KEYWORD false) otherwise.
     */
    bool equal(T)(T a, T b)
    {
        return a == b;
    }

    static foreach (Arg; Args)
    {
        /**
         * Overloaded, configurable method that tests whether $(D_PARAM a) is
         * equal to $(D_PARAM b).
         *
         * Params:
         *     a = Left-hand side operand. 
         *     b = Right-hand side operand.
         *
         * Returns: $(D_KEYWORD true) if `a == b`, $(D_KEYWORD false) otherwise.
         */
        bool equal(Arg.T a, Arg.T b)
        {
            return Arg.compare(a, b);
        }
    }
}
