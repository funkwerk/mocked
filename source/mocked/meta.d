module mocked.meta;

import std.format : format;
import std.meta;

struct Maybe(Arguments...)
{
    private Arguments arguments = Arguments.init;
    private bool isNull_ = true;

    public enum size_t length = Arguments.length;

    public static Maybe!Arguments opCall(Arguments arguments)
    {
        typeof(return) ret;

        ret.arguments = arguments;
        ret.isNull_ = false;

        return ret;
    }

    public void opAssign(Arguments arguments)
    {
        this.arguments = arguments;
        this.isNull_ = false;
    }

    public @property bool isNull()
    {
        return this.isNull_;
    }

    public @property ref Arguments[n] get(size_t n)()
    if (n < Arguments.length)
    in (!this.isNull())
    {
        return this.arguments[n];
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
