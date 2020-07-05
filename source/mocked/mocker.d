module mocked.mocker;

import mocked.builder;
import mocked.error;
import mocked.meta;
import mocked.option;
import std.algorithm;
import std.container.dlist;
import std.conv;
import std.format : format;
import std.traits;

private enum string mockCode = q{
    auto overloads = &expectationSetup.expectationTuple[j].overloads[i];

    overloads.find!(call => call.repeat_ != 0
            || call.ignoreArgs_
            || call.compareArguments!Options(arguments));

    if (overloads.empty)
    {
        throw unexpectedCallError!(typeof(super), Overload.ParameterTypes)(expectation.name, arguments);
    }
    if (overloads.front.repeat_ > 0 && !overloads.front.ignoreArgs_
            && !overloads.front.compareArguments!Options(arguments))
    {
        auto overloadArguments = overloads.front.arguments;

        overloads.clear();

        throw unexpectedArgumentError!(typeof(super),
                Overload.ParameterTypes, Overload.Arguments)(
                expectation.name, arguments, overloadArguments);
    }

    scope(exit)
    {
        if (overloads.front.repeat_ > 1)
        {
            --overloads.front.repeat_;
        }
        else if (overloads.front.repeat_ == 1)
        {
            overloads.popFront;
        }
    }

    static if (is(Overload.Return == void))
    {
        if (overloads.front.action_ !is null)
        {
            overloads.front.action_(arguments);
        }
    }
    else
    {
        Overload.Return ret = void;

        if (overloads.front.action_ !is null)
        {
            ret = overloads.front.action_(arguments);
        }
        else
        {
            ret = overloads.front.return_;
        }
    }

    static if (!is(T == interface) && is(Overload.Return == void))
    {
        if (overloads.front.passThrough_)
        {
            __traits(getMember, super, expectation.name)(arguments);
        }
    }
    else static if (!is(T == interface))
    {
        if (overloads.front.passThrough_)
        {
            ret = __traits(getMember, super, expectation.name)(arguments);
        }
    }

    static if (!canFind!("nothrow", Overload.qualifiers))
    {
        if (overloads.front.exception !is null)
        {
            throw overloads.front.exception;
        }
    }
    static if (!is(Overload.Return == void))
    {
        return ret;
    }
};

private enum string stubCode = q{
    auto overloads = expectationSetup.expectationTuple[j].overloads[i];
    auto match = overloads.find!(call => call.compareArguments!Options(arguments));

    static if (is(Overload.Return == void))
    {
        if (match.front.action_ !is null)
        {
            match.front.action_(arguments);
        }
    }
    else
    {
        Overload.Return ret = void;

        if (match.front.action_ !is null)
        {
            ret = match.front.action_(arguments);
        }
        else
        {
            ret = match.front.return_;
        }
    }

    static if (!is(T == interface) && is(Overload.Return == void))
    {
        if (match.front.passThrough_)
        {
            __traits(getMember, super, expectation.name)(arguments);
        }
    }
    else static if (!is(T == interface))
    {
        if (match.front.passThrough_)
        {
            ret = __traits(getMember, super, expectation.name)(arguments);
        }
    }

    static if (!canFind!("nothrow", Overload.qualifiers))
    {
        if (match.front.exception !is null)
        {
            throw match.front.exception;
        }
    }
    static if (!is(Overload.Return == void))
    {
        return ret;
    }
};

/**
 * Mocker instance with default options.
 *
 * See_Also: $(D_PSYMBOL Factory), $(D_PSYMBOL configure).
 */
alias Mocker = Factory!(Options!());

/**
 * Constructs a mocker with options passed as $(D_PARAM Args).
 *
 * Params:
 *     Args = Mocker options.
 *
 * See_Also: $(D_PSYMBOL Factory), $(D_PSYMBOL Mocker).
 */
auto configure(Args...)()
{
    return Factory!(Options!Args)();
}

/**
 * A class through which one creates mock objects and manages expectations
 * about calls to their methods.
 *
 * Params:
 *     Options = Mocker $(D_PSYMBOL Options).
 *
 * See_Also: $(D_PSYMBOL Mocker), $(D_PSYMBOL CustomMocker).
 */
struct Factory(Options)
{
    private DList!Verifiable repositories;
    //private enum Options options = Options();

    /**
     * Mocks the type $(D_PARAM T).
     *
     * Params:
     *     T = The type to mock.
     *     Args = Constructor parameter types.
     *     args = Constructor arguments.
     *
     * Returns: A mock builder.
     */
    auto mock(T, Args...)(Args args)
    {
        auto mock = new Mock!(T, Options, mockCode, Args)(args);
        auto mocked = new Mocked!(typeof(mock))(mock);

        this.repositories.insertBack(mocked);
        return mocked;
    }

    /**
     * Stubs the type $(D_PARAM T).
     *
     * Params:
     *     T = The type to stub.
     *     Args = Constructor parameter types.
     *     args = Constructor arguments.
     *
     * Returns: A stub builder.
     */
    auto stub(T, Args...)(Args args)
    if (isPolymorphicType!T)
    {
        auto stub = new Mock!(T, Options, stubCode, Args)(args);

        return new Stubbed!(typeof(stub))(stub);
    }

    /**
     * Verifies that certain expectation requirements were satisfied.
     *
     * Throws: $(D_PSYMBOL ExpectationViolationException) if those issues occur.
     */
    void verify()
    {
        this.repositories.each!(repository => repository.verify);
    }

    ~this()
    {
        verify;
    }
}

/**
 * Stub builder.
 *
 * Params:
 *     T = Mocked type.
 */
final class Stubbed(StubT) : Builder!StubT
{
    /**
     * Params:
     *     mock = Mocked object.
     */
    this(StubT mock)
    {
        this.mock = mock;
    }

    /**
     * Returns: Repository used to set up stubbed methods.
     */
    ref auto stub()
    {
        return this.mock.expectationSetup;
    }

    alias get this;
}
