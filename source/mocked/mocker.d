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
    %2$s Overload.Return %1$s(Overload.ParameterTypes arguments)
    {
        auto overloads = repository.expectationTuple[j].overloads[i];

        if (overloads.empty)
        {
            throw unexpectedCallError!(typeof(super), Overload.ParameterTypes)("%1$s", arguments);
        }
        if (!overloads.front.ignoreArgs_
                && !overloads.front.compareArguments!options(arguments))
        {
            repository.expectationTuple[j].overloads[i].clear();

            throw unexpectedArgumentError!(typeof(super),
                    Overload.ParameterTypes, Overload.Arguments)(
                    "%1$s", arguments, overloads.front.arguments);
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
                __traits(getMember, super, "%1$s")(arguments);
            }
        }
        else static if (!is(T == interface))
        {
            if (overloads.front.passThrough_)
            {
                ret = __traits(getMember, super, "%1$s")(arguments);
            }
        }

        if (repository.expectationTuple[j].overloads[i].front.repeat_ > 1)
        {
            --repository.expectationTuple[j].overloads[i].front.repeat_;
        }
        else if (repository.expectationTuple[j].overloads[i].front.repeat_ == 1)
        {
            repository.expectationTuple[j].overloads[i].popFront;
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
    }
};

private enum string stubCode = q{
    %2$s Overload.Return %1$s(Overload.ParameterTypes arguments)
    {
        auto overload = repository.expectationTuple[j].overloads[i];
        auto match = overload.find!(call => call.compareArguments!options(arguments));

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
                __traits(getMember, super, "%1$s")(arguments);
            }
        }
        else static if (!is(T == interface))
        {
            if (match.front.passThrough_)
            {
                ret = __traits(getMember, super, "%1$s")(arguments);
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
    private enum Options options = Options();

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
        Repository!T repository;

        mixin NestedMock!mockCode;

        auto mock = new Mock();
        auto mocked = new Mocked!T(mock, repository);

        this.repositories.insertBack(mocked);
        return mocked;
    }

    /**
     * Stubs the type $(D_PARAM T).
     *
     * Params:
     *     T = The type to stub.
     *     Args = Constructor parameter types.
     *     Args = Constructor arguments.
     *
     * Returns: A stub builder.
     */
    auto stub(T, Args...)(Args args)
    if (isPolymorphicType!T)
    {
        Repository!T repository;

        mixin NestedMock!stubCode;

        auto stub = new Mock();

        return new Stubbed!T(stub, repository);
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
final class Stubbed(T) : Builder!T
{
    /**
     * Params:
     *     mock = Mocked object.
     *     repository = Repository used to set up expectations.
     */
    this(T mock, ref Repository!T repository)
    {
        get = mock;
        this.repository = &repository;
    }

    /**
     * Returns: Repository used to set up stubbed methods.
     */
    ref Repository!T stub()
    {
        return *this.repository;
    }

    alias get this;
}
