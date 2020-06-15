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
}

/**
 * Takes a sequence of strings and joins them with separating spaces.
 *
 * Params:
 *     Args = Strings.
 *
 * Returns: Concatenated string.
 */
template unwords(Args...)
{
    static if (Args.length == 0)
    {
        enum string unwords = "";
    }
    else static if (Args.length == 1)
    {
        enum string unwords = Args[0];
    }
    else
    {
        enum string unwords = format!"%s %s"(Args[0], unwords!(Args[1..$]));
    }
}

enum bool isPolymorphicType(T) = is(T == class) || is(T == interface);

enum bool canFind(alias T, Args...) = staticIndexOf!(T, Args) != -1;
