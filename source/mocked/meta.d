module mocked.meta;

import std.format : format;
import std.meta;
import std.typecons;

/**
 * $(D_PSYMBOL Maybe) optionally saves a tuple of values. The values can't be
 * set individually, but only at once.
 */
struct Maybe(Arguments...)
{
    private Nullable!(Tuple!Arguments) arguments_;

    /// Tuple length.
    public enum size_t length = Arguments.length;

    /**
     * Params:
     *     arguments = Values to be assigned.
     */
    public void opAssign(Arguments arguments)
    {
        this.arguments_ = tuple!Arguments(arguments);
    }

    /**
     * Returns: $(D_KEYWORD true) if the tuple is set, $(D_KEYWORD false)
     * otherwise.
     */
    public @property bool isNull()
    {
        return this.arguments_.isNull;
    }

    /**
     * Params:
     *     n = Value position in the tuple.
     *
     * Returns: nth value in the tuple.
     */
    public @property ref Arguments[n] get(size_t n)()
    if (n < Arguments.length)
    in (!this.isNull())
    {
        return this.arguments_.get[n];
    }

    /**
     * Returns: Value tuple.
     *
     * Preconditions:
     *
     * $(D_CODE !isNull).
     */
    public @property ref Tuple!Arguments get()
    in (!isNull)
    {
        return this.arguments_.get;
    }
}

/**
 * Holds a typed sequence of template parameters.
 *
 * Params:
 *     Args = Elements of this $(D_PSYMBOL Pack).
 */
struct Pack(Args...)
{
    /// Elements in this tuple as $(D_PSYMBOL AliasSeq).
    alias Seq = Args;

    /// The length of the tuple.
    enum size_t length = Args.length;

    alias Seq this;
}

/**
 * Params:
 *     T = Some type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a class or interface,
 * $(D_KEYWORD false) otherwise.
 */
enum bool isPolymorphicType(T) = is(T == class) || is(T == interface);

enum bool canFind(alias T, Args...) = staticIndexOf!(T, Args) != -1;
