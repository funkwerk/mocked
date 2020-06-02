module mocked.error;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.typecons;

/**
 * Constructs an $(D_PSYMBOL UnexpectedCallError).
 *
 * Params:
 *     T = Object type.
 *     Args = $(D_PARAM name)'s arguments.
 *     name = Unexpected call name.
 *     arguments = $(D_PARAM name)'s arguments.
 *     file = File.
 *     line = Line number.
 *     nextInChain = The next error.
 *
 * Returns: $(D_PSYMBOL UnexpectedCallError).
 */
UnexpectedCallError unexpectedCallError(T, Args...)(
        string name, Args arguments,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
{
    string[] formattedArguments;

    static foreach (i, Arg; Args)
    {
        formattedArguments ~= to!string(arguments[i]);
    }
    return new UnexpectedCallError(formatName!T(name),
            formattedArguments, file, line, nextInChain);
}

private string formatName(T)(string name)
{
    return format!"%s.%s"(T.stringof, name);
}

/**
 * Thrown when an unexpected call occurs.
 */
final class UnexpectedCallError : Error
{
    private string name;
    private string[] arguments;

    /**
     * Constructs an $(D_PSYMBOL UnexpectedCallError).
     *
     * Params:
     *     Args = $(D_PARAM name)'s arguments.
     *     name = Unexpected call name.
     *     arguments = $(D_PARAM name)'s arguments.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, string[] arguments,
            string file = __FILE__, size_t line = __LINE__,
            Throwable nextInChain = null)
    {
        this.name = name;
        this.arguments = arguments;

        super("Unexpected call", file, line, nextInChain);
    }

    public override string toString()
    {
        return format!"%s: %s(%(%s, %))"(this.msg, this.name, this.arguments);
    }
}

/**
 * Constructs an $(D_PSYMBOL UnexpectedArgumentError).
 *
 * $(D_PARAM arguments) contains both actual and expected arguments. First the
 * actual arguments are given. The last argument in $(D_PARAM Args) is a
 * $(D_PSYMBOL Maybe) containing the expected arguments.
 *
 * Params:
 *     T = Object type.
 *     Args = $(D_PARAM name)'s actual and expected arguments.
 *     name = Unexpected call name.
 *     arguments = $(D_PARAM name)'s actual and expected arguments.
 *     file = File.
 *     line = Line number.
 *     nextInChain = The next error.
 */
UnexpectedArgumentError unexpectedArgumentError(T, Args...)(
        string name, Args arguments,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
{
    ExpectationPair[] formattedArguments;

    static foreach (i, Arg; Args[0 .. $ - 1])
    {{
        auto expected = to!string(arguments[$ - 1].get!i);
        auto actual = to!string(arguments[i]);

        formattedArguments ~= ExpectationPair(actual, expected);
    }}

    return new UnexpectedArgumentError(formatName!T(name),
            formattedArguments, file, line, nextInChain);
}

/// Pair containing the expected argument and the argument from the actual call.
alias ExpectationPair = Tuple!(string, "actual", string, "expected");

/**
 * Error thrown when a method has been called with arguments that don't match
 * the expected ones.
 */
final class UnexpectedArgumentError : Error
{
    private string name;
    private ExpectationPair[] arguments;

    /**
     * Constructs an $(D_PSYMBOL UnexpectedArgumentError).
     *
     * Params:
     *     T = Object type.
     *     Args = $(D_PARAM name)'s actual and expected arguments.
     *     name = Unexpected call name.
     *     arguments = $(D_PARAM name)'s actual and expected arguments.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, ExpectationPair[] arguments,
            string file, size_t line, Throwable nextInChain)
    {
        this.name = name;
        this.arguments = arguments;

        super("Expectation failure", file, line, nextInChain);
    }

    public override string toString()
    {
        auto message = appender!string();

        message ~= format!"%s\n"(this.msg);

        auto actual = map!(argument => argument.actual)(arguments);
        auto expected = map!(argument => argument.expected)(arguments);

        message ~= format!"  Expected: %s(%(%s, %))\n"(this.name, expected);
        message ~= format!"  but got: %s(%(%s, %))\n"(this.name, actual);

        return message.data;
    }
}

/**
 * Thrown if a method was expected to be called, but wasn't.
 */
final class ExpectationViolationException : Exception
{
    this(string msg, string file = __FILE__, size_t line = __LINE__,
            Throwable nextInChain = null)
    {
        super(msg, file, line, nextInChain);
    }
}
