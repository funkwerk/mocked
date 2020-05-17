module mocked.mocker;

import mocked.builder;
import mocked.repository;
import std.conv;
import std.format : format;
import std.traits;

private enum string overloadingCode = q{
    override Overload.Return %1$s(Overload.Arguments arguments)
    {
        auto overloads = __traits(getMember, builder, "%1$s").overloads[i];

        if (overloads.empty)
        {
            return __traits(getMember, super, "%1$s")(arguments);
        }
        static foreach (j, argument; arguments)
        {
            if (!overloads.front.arguments.isNull
                && overloads.front.arguments.get!j != argument)
            {
                throw new ExpectationViolationError("Expectation failure");
            }
        }

        static if (!is(Overload.Return == void))
        {
            auto ret = overloads.front.return_;
        }
        __traits(getMember, builder, "%1$s").overloads[i].popFront;

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
        Builder!T builder;

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
                    mixin(format!overloadingCode(expectation.name));
                }
            }
        }

        auto mock = new Mocked();
        auto repository = new Repository!T(mock, builder);

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
        this.verify;
    }
}
