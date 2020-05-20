module mocked.mocker;

import mocked.builder;
import mocked.error;
import mocked.repository;
import std.conv;
import std.format : format;
import std.traits;

private enum string overloadingCode = q{
    %2$s Overload.Return %1$s(Overload.Arguments arguments) %3$s
    {
        auto overloads = __traits(getMember, builder, "%1$s").overloads[i];

        if (overloads.empty)
        {
            throw new ExpectationViolationError("Unexpected call");
        }
        if (!overloads.front.ignoreArgs_ && !overloads.front.compareArguments(arguments))
        {
            throw new ExpectationViolationError("Expectation failure");
        }

        static if (is(T == interface) && !is(Overload.Return == void))
        {
            Overload.Return ret = overloads.front.return_;
        }
        else static if (!is(Overload.Return == void))
        {
            Overload.Return ret = void;
            if (overloads.front.passThrough_)
            {
                ret = __traits(getMember, super, "%1$s")(arguments);
            }
            else
            {
                ret = overloads.front.return_;
            }
        }
        else static if (!is(T == interface))
        {
            if (overloads.front.passThrough_)
            {
                __traits(getMember, super, "%1$s")(arguments);
            }
        }
        if (__traits(getMember, builder, "%1$s").overloads[i].front.repeat_ > 1)
        {
            --__traits(getMember, builder, "%1$s").overloads[i].front.repeat_;
        }
        else if (__traits(getMember, builder, "%1$s").overloads[i].front.repeat_ == 1)
        {
            __traits(getMember, builder, "%1$s").overloads[i].popFront;
        }

        static if (!is(Overload.Return == void))
        {
            return ret;
        }
    }
};

struct Mocker
{
    Verifiable[] repositories;

    // Implementation
    auto mock(T, Args...)(Args args)
    {
        Repository!T builder;

        class Mocked : T
        {
            static if (__traits(hasMember, T, "__ctor") && Args.length > 0)
            {
                this()
                {
                    super(args);
                }
            }
            else static if (__traits(hasMember, T, "__ctor"))
            {
                this()
                {
                    super(Parameters!(T.__ctor).init);
                }
            }

            static foreach (expectation; builder.ExpectationTuple)
            {
                static foreach (i, Overload; expectation.Overloads)
                {
                    static if (is(T == class))
                    {
                        mixin(format!overloadingCode(expectation.name,
                                "override ", Overload.qualifiers));
                    }
                    else
                    {
                        mixin(format!overloadingCode(expectation.name,
                                "", Overload.qualifiers));
                    }
                }
            }
        }

        auto mock = new Mocked();
        auto repository = new Builder!T(mock, builder);

        this.repositories ~= repository;
        return repository;
    }

    void verify()
    {
        foreach (repository; this.repositories)
        {
            repository.verify;
        }
    }

    ~this()
    {
        verify;
    }
}
