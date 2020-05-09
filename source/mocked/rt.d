module mocked.rt;

import mocked.builder;
import std.conv;
import std.traits;
import tanya.meta.metafunction;

struct MockRepository(T)
{
    T mock;
    Builder!T* builder;

    @disable this();

    this(T mock, ref Builder!T builder)
    {
        this.mock = mock;
        this.builder = &builder;
    }

    ref Builder!T expect()
    {
        return *this.builder;
    }

    ref T getMock()
    {
        return this.mock;
    }

    alias getMock this;
}

template argumentValidation(string member, size_t j, Overloads...)
{
    template join(size_t i, string accumulator, Args...)
    {
        static if (Args.length == 0)
        {
            enum string join = accumulator;
        }
        else
        {
            enum string line = "if (!builder." ~ member ~ ".overloads[" ~ j.to!string
                ~ "].front.arguments.isNull && builder." ~ member ~ ".overloads["
                ~ j.to!string ~ "].front.arguments.get!("
                ~ i.to!string
                ~ ") != "
                ~ Args[0][1]
                ~ ") throw new ExpectationViolationError(\"Expectation failure\");";
            enum string join = join!(i + 1, accumulator ~ line, Args[1 .. $]);
        }
    }
    alias ParameterList = ZipWith!(Pack, Pack!(Overloads[j].Arguments),
            Pack!(Overloads[j].ArgumentIdentifiers));

    enum string argumentValidation = join!(0, "", ParameterList);
}

template arguments(Overload)
{
    template join(string accumulator, Args...)
    {
        static if (Args.length == 0)
        {
            enum string join = accumulator;
        }
        else
        {
            enum string join = join!(accumulator ~ Args[0][1] ~ ", ", Args[1 .. $]);
        }
    }
    alias ParameterList = ZipWith!(Pack, Pack!(Overload.Arguments),
            Pack!(Overload.ArgumentIdentifiers));

    enum arguments = join!("", ParameterList);
}
