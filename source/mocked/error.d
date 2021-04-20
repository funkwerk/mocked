module mocked.error;

import std.algorithm;
import std.array;
import std.conv;
import std.format;
import std.traits;
import std.typecons;

/**
 * Constructs an $(D_PSYMBOL UnexpectedCallError).
 *
 * Params:
 *     T = Object type.
 *     Args = $(D_PARAM name)'s argument types.
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
    return new UnexpectedCallError(formatName!T(name),
            formatArguments!Args(arguments), file, line, nextInChain);
}

private string[] formatArguments(Args...)(ref Args arguments)
{
    string[] formattedArguments;
    auto spec = singleSpec("%s");
    auto writer = appender!(char[])();

    static foreach (i, Arg; Args)
    {
        static if (isSomeString!Arg)
        {
            formattedArguments ~= format!"%(%s %)"([arguments[i]]);
        }
        else
        {
            writer.clear();
            writer.formatValue(arguments[i], spec);
            formattedArguments ~= writer[].idup;
        }
    }
    return formattedArguments;
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
     *     name = Unexpected call name.
     *     arguments = $(D_PARAM name)'s arguments.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, string[] arguments,
            string file = __FILE__, size_t line = __LINE__,
            Throwable nextInChain = null) pure @safe
    {
        this.name = name;
        this.arguments = arguments;

        const message = format!"Unexpected call: %s(%-(%s, %))"(this.name, this.arguments);

        super(message, file, line, nextInChain);
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
    auto spec = singleSpec("%s");
    auto writer = appender!(char[])();

    static foreach (i, Arg; Args[0 .. $ - 1])
    {{
        static if (isSomeString!Arg)
        {
            const expected = format!"%(%s %)"([arguments[$ - 1].get!i]);
            const actual = format!"%(%s %)"([arguments[i]]);
        }
        else
        {
            writer.clear();
            writer.formatValue(arguments[$ - 1].get!i, spec);
            const expected = writer[].idup;

            writer.clear();
            writer.formatValue(arguments[i], spec);
            const actual = writer[].idup;
        }

        formattedArguments ~= ExpectationPair(actual, expected);
    }}

    return new UnexpectedArgumentError(formatName!T(name),
            formattedArguments, file, line, nextInChain);
}

/// Pair containing the expected argument and the argument from the actual call.
private alias ExpectationPair = Tuple!(string, "actual", string, "expected");

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
     *     name = Unexpected call name.
     *     arguments = $(D_PARAM name)'s actual and expected arguments.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, ExpectationPair[] arguments,
            string file, size_t line, Throwable nextInChain) pure @safe
    {
        this.name = name;
        this.arguments = arguments;

        auto message = appender!string();

        message ~= "Expectation failure:\n";

        auto actual = arguments.map!(argument => argument.actual);
        auto expected = arguments.map!(argument => argument.expected);

        message ~= format!"  Expected: %s(%-(%s, %))\n"(this.name, expected);
        message ~= format!"  but got:  %s(%-(%s, %))"(this.name, actual);

        super(message.data, file, line, nextInChain);
    }
}

/**
 * Constructs an $(D_PSYMBOL OutOfOrderCallError).
 *
 * Params:
 *     T = Object type.
 *     Args = $(D_PARAM name)'s arguments.
 *     name = Unexpected call name.
 *     arguments = $(D_PARAM name)'s arguments.
 *     expected = Expected position in the call queue.
 *     got = Actual position in the call queue.
 *     file = File.
 *     line = Line number.
 *     nextInChain = The next error.
 */
OutOfOrderCallError outOfOrderCallError(T, Args...)(
        string name, Args arguments,
        size_t expected, size_t got,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
{
    return new OutOfOrderCallError(formatName!T(name),
            formatArguments!Args(arguments), expected, got, file, line, nextInChain);
}

/**
 * `OutOfOrderCallError` is thrown only if the checking the call order among
 * methods of the same class is enabled. The error is thrown if a method is
 * called earlier than expected.
 */
final class OutOfOrderCallError : Error
{
    private string name;
    private string[] arguments;

    /**
     * Constructs an $(D_PSYMBOL OutOfOrderCallError).
     *
     * Params:
     *     name = Unexpected call name.
     *     arguments = $(D_PARAM name)'s arguments.
     *     expected = Expected position in the call queue.
     *     got = Actual position in the call queue.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, string[] arguments,
            size_t expected, size_t got,
            string file, size_t line, Throwable nextInChain) pure @safe
    {
        this.name = name;
        this.arguments = arguments;

        string  message = format!"%s(%-(%s, %)) called too early:\n"(this.name, this.arguments);
        message ~= format!"Expected at position: %s, but got: %s"(expected, got);

        super(message, file, line, nextInChain);
    }
}

/**
 * Constructs an $(D_PSYMBOL ExpectationViolationException).
 *
 * Params:
 *     T = Object type.
 *     MaybeArgs = $(D_PARAM name)'s argument types.
 *     name = Call name.
 *     arguments = $(D_PARAM name)'s arguments.
 *     file = File.
 *     line = Line number.
 *     nextInChain = The next error.
 */
ExpectationViolationException expectationViolationException(T, MaybeArgs)(
        string name, MaybeArgs arguments,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
{
    string[] formattedArguments;
    auto writer = appender!(char[])();
    auto spec = singleSpec("%s");

    if (!arguments.isNull)
    {
        static foreach (i; 0 .. MaybeArgs.length)
        {
            static if (isSomeString!(MaybeArgs.Types[i]))
            {
                formattedArguments ~= format!"%(%s %)"([arguments.get!i]);
            }
            else
            {
                writer.clear();
                writer.formatValue(arguments.get!i, spec);
                formattedArguments ~= writer[].idup;
            }
        }
    }
    
    return new ExpectationViolationException(formatName!T(name),
            formattedArguments, file, line, nextInChain);
}

/**
 * Expected the method to be called n times, but called m times,
 * where m < n.
 * Same as unexpected call, but with expected arguments instead of the actual ones.
 * Thrown if a method was expected to be called, but wasn't.
 */
final class ExpectationViolationException : Exception
{
    private string name;
    private string[] arguments;

    /**
     * Constructs an $(D_PSYMBOL ExpectationViolationException).
     *
     * Params:
     *     name = Call name.
     *     arguments = $(D_PARAM name)'s arguments.
     *     file = File.
     *     line = Line number.
     *     nextInChain = The next error.
     */
    this(string name, string[] arguments, string file, size_t line, Throwable nextInChain)
    {
        this.name = name;
        this.arguments = arguments;

        const message = this.arguments is null
            ? format!"Expected method not called: %s"(this.name)
            : format!"Expected method not called: %s(%-(%s, %))"(this.name, this.arguments);

        super(message, file, line, nextInChain);
    }
}
