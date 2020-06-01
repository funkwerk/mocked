module mocked.error;

import std.conv;
import std.format;
import std.exception;

/**
 * Constructs an $(D_PSYMBOL UnexpectedCallError).
 *
 * Params:
 *     name = Unexpected call name.
 *     arguments = $(D_PARAM name)'s arguments.
 *     file = File.
 *     line = Line number.
 *     nextInChain = The next error.
 *
 * Returns: $(D_PSYMBOL UnexpectedCallError).
 */
UnexpectedCallError unexpectedCallError(Args...)(
        string name, Args arguments,
        string file = __FILE__, size_t line = __LINE__,
        Throwable nextInChain = null)
{
    string[] formattedArguments;

    static foreach (i, Arg; Args)
    {
        formattedArguments ~= to!string(arguments[i]);
    }

    return new UnexpectedCallError(name, formattedArguments, file, line, nextInChain);
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
 * Error thrown when a method has been called with arguments that don't match
 * the expected ones.
 */
final class UnexpectedArgumentError : Error
{
    mixin basicExceptionCtors;
}

final class ExpectationViolationException : Exception
{
    mixin basicExceptionCtors;
}
