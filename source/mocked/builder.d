module mocked.builder;

import mocked.repository;
import mocked.error;
import std.meta;

interface Verifiable
{
    void verify();
}

final class Builder(T) : Verifiable
{
    T mock;
    Repository!T* builder;

    this(T mock, ref Repository!T builder)
    {
        this.mock = mock;
        this.builder = &builder;
    }

    ref Repository!T expect()
    {
        return *this.builder;
    }

    ref T getMock() @nogc nothrow pure @safe
    {
        return this.mock;
    }

    void verify()
    {
        static foreach (expectation; this.builder.ExpectationTuple)
        {
            static foreach (i, Overload; expectation.Overloads)
            {
                if (!__traits(getMember, builder, expectation.name).overloads[i].empty
                        && __traits(getMember, builder, expectation.name).overloads[i].front.repeat_ > 0)
                {
                    throw new ExpectationViolationError("Expected method not called");
                }
            }
        }
    }

    static if (is(T == class))
    {
        override size_t toHash()
        {
            return getMock().toHash();
        }

        override string toString()
        {
            return getMock().toString();
        }

        override int opCmp(Object o)
        {
            return getMock().opCmp(o);
        }

        override bool opEquals(Object o)
        {
            return getMock().opEquals(o);
        }
    }

    alias getMock this;
}
